# Server-to-server confirmation from Monri. Retried by Monri until it gets a 200.
module Monri
  class CallbacksController < ActionController::Base
    skip_forgery_protection

    def create
      raw_body = request.raw_post
      return head :unauthorized unless Monri::Gateway.valid_callback?(raw_body, request.authorization)

      data = JSON.parse(raw_body)
      payment = Payment.find_by(order_number: data["order_number"])
      return head :ok unless payment # unknown order: acknowledge so Monri stops retrying

      if data["status"] == "approved" && data["amount"].to_i == payment.amount_cents && data["currency"] == payment.currency
        payment.approve!(data.except("pan_token"))
      else
        payment.decline!(data.except("pan_token"))
      end
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end
  end
end
