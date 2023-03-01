class Axis

  attr_accessor :api_token

  def initialize
    get_auth_token
    @current_progress = 0
  end

  def loop_products
    products = ShopifyAPI::Product.find(:all, params: {limit: 250})
    match_inventory(products)

    while products.next_page? do 
      products = products.fetch_next_page
      match_inventory(products)
    end
  end

  def match_inventory(products)

    for product in products
      if @current_progress < AppDatum.first.progress
        @current_progress += 1
        next
      end

      barcodes = product.variants.map{|v| v.barcode}
      gearfire_products = get_gearfire_products(barcodes)

      next unless gearfire_products

      if gearfire_products["message"] == "Authorization has been denied for this request."
        get_auth_token

        gearfire_products = get_gearfire_products(barcodes)
        next unless gearfire_products
      end

      gearfire_inventory = {}
      gearfire_products["axisContent"]["data"].map{|d|
        calculated_inv = d["storeInventory"].first["qoh"] - d["storeInventory"].first["qtyCommitted"]
        gearfire_inventory[d["productUPC"]] = {
          "inventory" => calculated_inv,
          "price" => d["storeInventory"].first["retailPrice"]
        }
      }

      if ShopifyAPI.credit_left < 5
        sleep 5
      end

      for variant in product.variants
        next unless gearfire_inventory[variant.barcode]
        puts ""
        old_inv = variant.inventory_quantity
        new_inv = gearfire_inventory[variant.barcode]["inventory"]
        puts "old_inv: #{old_inv} | new_inv: #{new_inv}"

        old_price = variant.price.to_f
        new_price = gearfire_inventory[variant.barcode]["price"].to_f
        puts "old_price: #{old_price} | new_price: #{new_price}"

        if new_price
          unless old_price == new_price
            variant.price = new_price
            ShopifyApiRetry.retry { variant.save }
            puts "changed price"
          end
        end

        if new_inv
          unless old_inv == new_inv
            params = { inventory_item_ids: variant.inventory_item_id }
            inventory_levels = ShopifyAPI::InventoryLevel.find(:all, params: params)
            inventory_levels[0].set(new_inv)
            puts "changed inv"
          end
        end
      end

      @current_progress += 1
    end

  end

  def get_gearfire_products(upcs)
    upc_filters = []
    for upc in upcs
      upc_filters << {"field":"productUPC","operator":"eq","value": upc.to_s}
    end

    upcs_json = upc_filters.to_json
    uri_string = "https://finandfeather1383.azurewebsites.net/api/ecomm/getproducts?{\"filter\":{\"logic\":\"or\",\"filters\":#{upcs_json}}}"

    url = URI(uri_string)
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(url)

    request["Authorization"] = auth_header
    request["Content-Type"] = 'application/json'

    attempt_count = 0
    max_attempts  = 3
    begin
      attempt_count += 1
      puts "attempt ##{attempt_count}"
      response = http.request(request)
    rescue OpenURI::HTTPError => e
      # it's 404, etc. (do nothing)
    rescue SocketError, Net::ReadTimeout => e
      # server can't be reached or doesn't send any respones
      puts "error: #{e}"
      sleep 3
      retry if attempt_count < max_attempts
    else
      # connection was successful,
      # content is fetched,
      # so here we can parse content with Nokogiri,
      # or call a helper method, etc.
      if response.read_body.include? "The resource you are looking for"
        return nil
      end

      JSON.parse response.read_body
    end
    
  end

  def get_auth_token
    url = URI('https://finandfeather1383.azurewebsites.net/token')

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(url)

    request.body = "username=#{ENV["GEARFIRE_USERNAME"]}&password=#{ENV["GEARFIRE_PASSWORD"]}&grant_type=password"
    response = http.request(request)
    response_json = JSON.parse response.read_body
    @api_token = response_json["access_token"]
    response_json["access_token"]
  end

  def post_sales(order_info)
    url = URI('https://finandfeather1383.azurewebsites.net/api/Ecomm/SalesOrder')

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(url)

    request.body = order_info.to_json

    request["Authorization"] = auth_header
    request["Content-Type"] = 'application/json'

    response = http.request(request)
    puts "."
    puts "."
    puts response.read_body
    puts "."
    puts "."
    JSON.parse response.read_body
  end

  def auth_header
    "Bearer #{@api_token}"
  end

  def show_token
    @api_token
  end

  def success(job)
    puts "THERE WE GO"
    app_datum = AppDatum.first
    app_datum.progress = 0
    app_datum.save
  end

  def error(job, exception)
    puts "PROBLEM"
    app_datum = AppDatum.first
    app_datum.progress = @current_progress
    app_datum.save
  end

  def failure(job)
    puts "FAILURE"
    app_datum = AppDatum.first
    app_datum.progress = 0
    app_datum.save
  end

end