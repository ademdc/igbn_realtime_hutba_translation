module Admin
  class AccountsController < BaseController
    PER_PAGE = 50
    STATUS_FILTERS = %w[trialing trial_expired active suspended].freeze

    before_action :set_account, except: :index

    def index
      scope = Account.search(params[:q])
      scope = scope.public_send(status_scope(params[:status])) if STATUS_FILTERS.include?(params[:status])
      scope = scope.where(country: params[:country]) if params[:country].present?

      @page = [params[:page].to_i, 1].max
      @total = scope.count
      @accounts = scope.order(created_at: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
        .includes(:users)
      @countries = Account.where.not(country: nil).distinct.order(:country).pluck(:country)
    end

    def show
      @users = @account.users.order(:created_at)
      @sessions = @account.speaker_sessions.recent.limit(15)
      @period_minutes = @account.minutes_used
      @awaiting_transfers = @account.payments.awaiting_transfer.order(:created_at)
      @total_sessions = @account.speaker_sessions.count
      @total_listeners = @account.listener_connections.count
      @listeners_by_language = @account.listener_connections.group(:language).count
    end

    def update
      if @account.update(admin_params)
        if @account.custom_domain_enabled? && @account.requested_custom_domain.present? &&
           (@account.saved_change_to_requested_custom_domain? || @account.saved_change_to_custom_domain_enabled?)
          CustomDomainSetupJob.perform_later(@account)
        end
        redirect_to admin_account_path(@account), notice: "Account updated"
      else
        redirect_to admin_account_path(@account), alert: @account.errors.full_messages.to_sentence
      end
    end

    def extend_trial
      days = params[:days].to_i.clamp(1, 365)
      base = [@account.trial_ends_at, Time.current].compact.max
      @account.update!(status: "trialing", trial_ends_at: base + days.days)
      redirect_to admin_account_path(@account), notice: "Trial extended by #{days} days"
    end

    # Opens the mosque dashboard as its first owner, for support
    def impersonate
      owner = @account.users.owners.order(:created_at).first
      return redirect_to admin_account_path(@account), alert: "This account has no owner" unless owner

      Rails.logger.info "Admin #{current_user.email} impersonated #{owner.email} (account #{@account.subdomain})"
      redirect_to @account.url("/session/#{owner.generate_token_for(:handover)}"), allow_other_host: true
    end

    private

    def set_account
      @account = Account.find(params[:id])
    end

    def status_scope(status)
      { "trialing" => :trialing, "trial_expired" => :trial_expired, "active" => :paying, "suspended" => :suspended }.fetch(status)
    end

    def admin_params
      params.require(:account).permit(:status, :extra_languages, :weekly_minutes_limit, :name, :custom_domain, :custom_domain_enabled, :requested_custom_domain)
    end
  end
end
