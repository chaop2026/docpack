Rails.application.routes.draw do
  # Permanent slug renames for the static SafeFile guide posts. These must come
  # before the "/blog/:slug" route below so they win; after the folder rename the
  # old paths no longer resolve as static files and fall through to here.
  # 301 (redirect default) — never reverse. Rails matches the routes with or
  # without a trailing slash, so both /blog/rrn-masking and /blog/rrn-masking/
  # are covered. The locale prefix is preserved in the target so a Spanish reader
  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist/).
  OLD_BLOG_SLUGS = {
    "rrn-masking"        => "resident-number-masking",
    "contract-checklist" => "contract-sharing-checklist"
  }.freeze

  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}/")
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}/")
    end
  end

  # Locale-prefixed public pages. Korean (default) uses bare paths; the
  # constraint only matches en/ja/es, so /ko/... never resolves here.
  scope "(:locale)", locale: /en|ja|es/ do
    root "pages#home"

    resources :conversions, only: [:create, :show] do
      member do
        get :download
      end
    end

    get "/compress", to: "pages#compress"
    get "/pdf",      to: "pages#pdf"
    get "/social",   to: "pages#social"
    get "/about",    to: "pages#about"
    get "/faq",      to: "pages#faq"

    get "/blog",       to: "posts#index", as: :blog
    get "/blog/:slug", to: "posts#show",  as: :blog_post
  end

  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
  get  "/safe",          to: redirect("/safe/")
  post "/api/safe_scan", to: "api/safe_scan#create"

  namespace :admin do
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :posts do
      member do
        post :generate
        post :improve
        post :publish
      end
      collection do
        post :auto_generate
      end
    end

    resources :banners do
      member do
        patch :toggle
        patch :move
      end
    end

    resources :blog_styles do
      member do
        post :analyze
        post :toggle
      end
    end

    root to: "banners#index"
  end

  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  get "up" => "rails/health#show", as: :rails_health_check
end
