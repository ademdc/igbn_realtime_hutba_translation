Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Search engines: per-host robots.txt, sitemap for the marketing site
  get "robots.txt", to: "seo#robots", format: false
  get "sitemap.xml", to: "seo#sitemap", defaults: { format: :xml }, format: false, constraints: AppDomain

  # Monri payment confirmations (any host)
  post "monri/callback", to: "monri/callbacks#create"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Marketing site on the apex domain (and www), e.g. hutba.app/de
  constraints(AppDomain) do
    get "/", to: "marketing#locale_redirect", as: :marketing_root
    scope ":locale", locale: Regexp.union(MarketingController::LOCALES) do
      get "/", to: "marketing#index", as: :marketing
      get "signup", to: "signups#new", as: :signup
      post "signup", to: "signups#create", as: nil
      get "signup/check", to: "signups#check", as: :signup_check
      get "terms", to: "marketing#terms", as: :marketing_terms
      get "login", to: "account_lookups#new", as: :marketing_login
      post "login", to: "account_lookups#create", as: nil
      get "impressum", to: "marketing#imprint", as: :marketing_imprint
      get "privacy", to: "marketing#privacy", as: :marketing_privacy
      get "blog", to: "blog#index", as: :blog
      get "blog/:slug", to: "blog#show", as: :blog_post
    end
  end

  # Mosque subdomains: the speaker panel is the root
  root "speaker#index"

  # Mosque user accounts
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  resources :password_resets, only: [:new, :create, :edit, :update], param: :token
  get "invitation/:token", to: "invitations#edit", as: :invitation
  patch "invitation/:token", to: "invitations#update"

  # Sign-in handover from the signup on the marketing site
  get "session/:token", to: "handovers#show", as: :handover

  # Mosque owner area
  get "dashboard", to: "dashboard#show", as: :dashboard
  patch "dashboard/account", to: "accounts#update", as: :account
  get "dashboard/qr/:language", to: "qr_codes#show", as: :qr_code,
    constraints: { language: Regexp.union(Language::CODES), format: /svg|png/ }
  get "dashboard/poster", to: "posters#show", as: :poster
  get "dashboard/billing", to: "billing#show", as: :billing
  post "dashboard/billing/checkout", to: "billing#checkout", as: :billing_checkout
  get "dashboard/billing/success", to: "billing#success", as: :billing_success
  resources :users, path: "dashboard/team", only: [:index, :create, :destroy]

  # Admin backoffice
  namespace :admin do
    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout
    get "dashboard", to: "dashboard#index", as: :dashboard
    resources :accounts, only: [:index, :show, :update] do
      member do
        post :extend_trial
        post :impersonate
      end
    end
    post "reset_speakers", to: "dashboard#reset_speakers", as: :reset_speakers
    post "reset_listeners", to: "dashboard#reset_listeners", as: :reset_listeners
    post "reset_all", to: "dashboard#reset_all", as: :reset_all
    root to: redirect("/admin/dashboard")
  end

  # Speaker authentication
  get "speaker/login", to: "speaker#login", as: :speaker_login
  post "speaker/authenticate", to: "speaker#authenticate", as: :speaker_authenticate
  delete "speaker/logout", to: "speaker#logout", as: :speaker_logout

  # Listener language selection
  get "listener", to: "listener#index", as: :listener

  # Big-screen view for a TV or projector in the mosque: /tv (all languages) or /tv/de
  get "tv", to: "listener#tv", as: :tv
  get "tv/:language", to: "listener#tv", as: :tv_language,
    constraints: { language: Regexp.union(Language::CODES) }

  # Language-specific listener pages, e.g. /de, /en
  get ":language", to: "listener#show", as: :listener_language,
    constraints: { language: Regexp.union(Language::CODES) }

  # Old full-name URLs (/german, /deutsch) from the single-tenant version
  get ":legacy", to: redirect { |params, _| "/#{Language::LEGACY_NAMES[params[:legacy]]}" },
    constraints: { legacy: Regexp.union(Language::LEGACY_NAMES.keys) }
end
