class Axis

  attr_accessor :api_token

  def initialize
    get_auth_token
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
      barcodes = product.variants.map{|v| v.barcode}
      gearfire_products = get_gearfire_products(barcodes)
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

        old_price = variant.inventory_quantity.to_f
        new_price = gearfire_inventory[variant.barcode]["price"].to_f
        puts "old_price: #{old_price} | new_price: #{new_price}"

        if new_price
          unless old_price == new_price
            variant.price = new_price
            variant.save
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

    response = http.request(request)

    JSON.parse response.read_body
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

end