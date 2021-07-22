class Axis

  attr_accessor :api_token

  def initialize
    get_auth_token
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