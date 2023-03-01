class OrderController < ApplicationController

  skip_before_action :verify_authenticity_token

  def from_shopify
    puts params

    order_info = {
      "SalesOrderDetails": [],
      "StoreId": 1,
      "SalesOrderNumber": params["name"],
      "SalesOrderDate": params["created_at"].split('T').first,
      "ShippingCost": params["total_shipping_price_set"]["shop_money"]["amount"].to_f,
      "TotalTax": params["total_tax_set"]["shop_money"]["amount"].to_f,
      "Notes": params["note"]
    }

    if params["billing_address"]
      order_info["BillToPerson"] = {
        "FirstName": params["billing_address"]["first_name"],
        "LastName": params["billing_address"]["last_name"],
        "Address1": params["billing_address"]["address1"],
        "Address2": params["billing_address"]["address2"],
        "City": params["billing_address"]["city"],
        "State": params["billing_address"]["province_code"],
        "Zip": params["billing_address"]["zip"],
        "Country": params["billing_address"]["country_code"],
        "EmailAddress": params["email"]
      }
    end

    if params["shipping_address"]
      order_info["ShipToPerson"] = {
        "FirstName": params["shipping_address"]["first_name"],
        "LastName": params["shipping_address"]["last_name"],
        "Address1": params["shipping_address"]["address1"],
        "Address2": params["shipping_address"]["address2"],
        "City": params["shipping_address"]["city"],
        "State": params["shipping_address"]["province_code"],
        "Zip": params["shipping_address"]["zip"],
        "Country": params["shipping_address"]["country_code"]
      }
    end

    for line_item in params["line_items"]

      barcode = ShopifyAPI::Variant.find(line_item["variant_id"]).barcode

      if barcode
        order_info[:SalesOrderDetails] << { 
          "ProductUpc": barcode,
          "QtyOrdered": line_item["quantity"],
          "PriceCharged": line_item["price"]
        }
      end
    end

    axis = Axis.new
    puts "order_info:"
    puts order_info
    puts "--"
    axis.post_sales(order_info)

    head :ok, content_type: "text/html"
  end

end