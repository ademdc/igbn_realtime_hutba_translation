# Downloadable QR codes for each listener language.
class QrCodesController < ApplicationController
  include AccountScoped
  include Authentication

  before_action :require_owner

  def show
    language = params[:language]
    return head :not_found unless Current.account.offers_language?(language)

    qr = RQRCode::QRCode.new(Current.account.url("/#{language}"), level: :m)
    filename = "hutba-#{Current.account.subdomain}-#{language}"

    respond_to do |format|
      format.svg do
        send_data qr.as_svg(module_size: 10, standalone: true, use_path: true, viewbox: true),
          type: "image/svg+xml", filename: "#{filename}.svg"
      end
      format.png do
        send_data qr.as_png(size: 1200, border_modules: 2).to_s,
          type: "image/png", filename: "#{filename}.png"
      end
    end
  end
end
