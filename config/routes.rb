Rails.application.routes.draw do
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
