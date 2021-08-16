require "shopify_api"

#
# Retry a ShopifyAPI request if an HTTP 429 (too many requests) is returned.
#
# ShopifyApiRetry.retry { customer.update_attribute(:tags, "foo")  }
# ShopifyApiRetry.retry(30) { customer.update_attribute(:tags, "foo") }
# c = ShopifyApiRetry.retry { ShopifyAPI::Customer.find(id) }
#
# By Skye Shaw (https://gist.github.com/sshaw/6043fa838e1cecf9d902)

module ShopifyApiRetry
  VERSION = "0.0.1".freeze
  HTTP_RETRY_AFTER = "Retry-After".freeze

  def retry
    raise ArgumentError, "block required" unless block_given?

    result = nil
    retried = 0

    begin
      result = yield
    rescue Errno::ECONNRESET => e
      if retried < 3
        puts Colorize.bright "Errno::ECONNRESET, retrying attempt ##{retried}"
        sleep 5

        retried += 1
        retry
      else
        puts Colorize.red "Errno::ECONNRESET not reconcilable, skipping"
        return false
      end
    rescue => e
      # Not 100% if we need to check for code method, I think I saw a NoMethodError...
      if retried < 3 && e.response.respond_to?(:code) && e.response.code.to_i != 404
        puts Colorize.bright "ShopifyAPI error #{e.response.code} retrying attempt ##{retried}"
        sleep 5

        retried += 1
        retry
      else
        puts Colorize.red "Skip, error not reconcilable #{e.response&.code}"
        return false
      end
    end

    result
  end

  module_function :retry
end