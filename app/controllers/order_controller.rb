class OrderController < ApplicationController

  skip_before_action :verify_authenticity_token

  def from_shopify
    puts params

    order_info = {
      "SalesOrderDetails": [],
      "SalesOrderNumber": params["name"],
      "SalesOrderDate": params["created_at"].split('T').first,
      "BillToPerson": {
        "FirstName": params["billing_address"]["first_name"],
        "LastName": params["billing_address"]["last_name"],
        "Address1": params["billing_address"]["address1"],
        "Address2": params["billing_address"]["address2"],
        "City": params["billing_address"]["city"],
        "State": params["billing_address"]["province_code"],
        "Zip": params["billing_address"]["zip"],
        "Country": params["billing_address"]["country_code"],
        "EmailAddress": params["email"],
        "PhoneNumber": params["billing_address"]["phone"]
      },
      "ShipToPerson": {
        "FirstName": params["shipping_address"]["first_name"],
        "LastName": params["shipping_address"]["last_name"],
        "Address1": params["shipping_address"]["address1"],
        "Address2": params["shipping_address"]["address2"],
        "City": params["shipping_address"]["city"],
        "State": params["shipping_address"]["province_code"],
        "Zip": params["shipping_address"]["zip"],
        "Country": params["shipping_address"]["country_code"],
        "PhoneNumber": params["shipping_address"]["phone"]
      },
      "ShippingCost": params["total_shipping_price_set"]["shop_money"]["amount"].to_f,
      "TotalTax": params["total_tax_set"]["shop_money"]["amount"].to_f,
      "Notes": params["note"]
    }

    for line_item in params["line_items"]
      order_info[:SalesOrderDetails] << { 
        "ProductUpc": line_item["id"],
        "QtyOrdered": line_item["quantity"],
        "PriceCharged": line_item["price"]
      }
    end

    axis = Axis.new
    puts "--"
    puts axis.auth_header
    puts "--"
    axis.post_sales(order_info)

    head :ok, content_type: "text/html"
  end

end