# Yearly plan and add-on languages, paid through Monri's hosted payment page.
class BillingController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :require_owner, except: :success
  before_action :require_user, only: :success

  def show
    @account = Current.account
    @payments = @account.payments.where.not(status: "pending").recent
  end

  def checkout
    @account = Current.account
    @account.assign_attributes(billing_params)

    unless @account.billing_details_complete? && @account.save
      @account.errors.add(:base, t("app.billing.details_missing")) if @account.errors.empty?
      @payments = @account.payments.where.not(status: "pending").recent
      return render :show, status: :unprocessable_entity
    end

    if buying_custom_domain? && @account.requested_custom_domain.blank?
      @account.errors.add(:requested_custom_domain, :blank)
      @payments = @account.payments.where.not(status: "pending").recent
      return render :show, status: :unprocessable_entity
    end

    @payment = build_payment
    return redirect_to billing_path, alert: t("app.billing.nothing_to_pay") unless @payment&.valid?

    @payment.save!
    @fields = Monri::Gateway.form_fields(
      @payment,
      success_url: Current.account.url("/dashboard/billing/success"),
      cancel_url: Current.account.url("/dashboard/billing"),
      callback_url: AppDomain.marketing_url("/monri/callback"),
      locale: I18n.locale
    )
    render :checkout, layout: false
  end

  # Monri redirects here after a successful payment
  def success
    payment = Current.account.payments.find_by(order_number: params[:order_number])

    if payment && Monri::Gateway.valid_return?(request.original_url)
      if params[:response_code] == "0000" && params[:amount].to_i == payment.amount_cents
        payment.approve!(request.query_parameters.except("digest", "pan_token"))
      end
      redirect_to billing_path, notice: t("app.billing.paid")
    else
      # The signed callback still confirms the payment if the redirect can't be verified
      redirect_to billing_path, alert: t("app.billing.unverified")
    end
  end

  private

  def billing_params
    params.require(:account).permit(:billing_name, :billing_address, :billing_zip, :billing_city,
                                    :billing_phone, :billing_email, :country, :requested_custom_domain)
  end

  # A newly booked own domain; mosques that already have one keep it on renewal
  def buying_custom_domain?
    params[:custom_domain] == "1" && !Current.account.custom_domain_enabled?
  end

  def build_payment
    extra = params[:extra_languages].to_i.clamp(0, 20)
    account = Current.account

    if account.paid_until&.future? && params[:kind] == "addon"
      if extra.positive? || buying_custom_domain?
        Payment.addon_for(account, user: current_user, extra_languages: extra, custom_domain: buying_custom_domain?)
      end
    else
      Payment.subscription_for(account, user: current_user, extra_languages: extra,
                               custom_domain: account.custom_domain_enabled? || buying_custom_domain?)
    end
  end
end
