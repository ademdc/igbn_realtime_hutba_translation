require "digest"

# Monri WebPay hosted payment form (https://ipg.monri.com/en/documentation/v2_form).
#
# ENV:
#   MONRI_AUTHENTICITY_TOKEN  merchant authenticity token
#   MONRI_MERCHANT_KEY        merchant key (used for all digests)
#   MONRI_ENV                 "production" for live payments, anything else uses ipgtest
module Monri
  class Gateway
    LANGUAGES = { "bs" => "ba", "hr" => "hr", "es" => "es" }.freeze

    class << self
      def configured?
        authenticity_token.present? && merchant_key.present?
      end

      def form_url
        production? ? "https://ipg.monri.com/v2/form" : "https://ipgtest.monri.com/v2/form"
      end

      def production?
        ENV["MONRI_ENV"] == "production"
      end

      # digest = SHA512(key + order_number + amount + currency)
      def form_digest(order_number, amount, currency)
        Digest::SHA512.hexdigest("#{merchant_key}#{order_number}#{amount}#{currency}")
      end

      # Success redirect: digest = SHA512(key + full success URL without the digest parameter)
      def valid_return?(url)
        digest = Rack::Utils.parse_query(URI(url).query)["digest"]
        return false if digest.blank?

        unsigned_url = url.sub(/[?&]digest=[^&]*\z/, "").sub(/digest=[^&]*&/, "")
        secure_compare(Digest::SHA512.hexdigest("#{merchant_key}#{unsigned_url}"), digest)
      end

      # Callback POST: "Authorization: WP3-callback <SHA512(key + raw body)>"
      def valid_callback?(raw_body, authorization)
        expected = "WP3-callback #{Digest::SHA512.hexdigest("#{merchant_key}#{raw_body}")}"
        secure_compare(expected, authorization.to_s)
      end

      def form_fields(payment, success_url:, cancel_url:, callback_url:, locale:)
        account = payment.account
        fields = {
          ch_full_name: account.billing_name.to_s.first(30),
          ch_address: account.billing_address.to_s.first(100),
          ch_city: account.billing_city.to_s.first(30),
          ch_zip: account.billing_zip.to_s.first(9),
          ch_country: account.country.to_s,
          ch_phone: account.billing_phone.to_s.first(30),
          ch_email: account.billing_email.to_s.first(100),
          order_info: payment.description.first(100),
          order_number: payment.order_number,
          amount: payment.amount_cents,
          currency: payment.currency,
          language: LANGUAGES.fetch(locale.to_s, "en"),
          transaction_type: "purchase",
          authenticity_token: authenticity_token,
          digest: form_digest(payment.order_number, payment.amount_cents, payment.currency),
          # Saved card makes renewal one click; MIT auto-charging needs acquirer approval first
          tokenize_pan_offered: "true"
        }
        # Monri only accepts HTTPS overrides; locally the URLs from the merchant dashboard apply
        { success_url_override: success_url, cancel_url_override: cancel_url, callback_url_override: callback_url }.each do |key, url|
          fields[key] = url if url.start_with?("https://")
        end
        fields
      end

      private

      def authenticity_token
        ENV["MONRI_AUTHENTICITY_TOKEN"]
      end

      def merchant_key
        ENV["MONRI_MERCHANT_KEY"]
      end

      def secure_compare(a, b)
        ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
      end
    end
  end
end
