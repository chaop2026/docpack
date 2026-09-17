Rails.application.routes.draw do
  # Permanent slug renames for the static SafeFile guide posts. These must come
  # before the "/blog/:slug" route below so they win; after the folder rename the
  # old paths no longer resolve as static files and fall through to here.
  # 301 (redirect default) — never reverse. Rails matches the routes with or
  # without a trailing slash, so both /blog/rrn-masking and /blog/rrn-masking/
  # are covered. The locale prefix is preserved in the target so a Spanish reader
  # stays in Spanish (/es/blog/contract-checklist → /es/blog/contract-sharing-checklist).
  #
  # The targets carry NO trailing slash (2026-09-18). They used to, and once
  # CanonicalPathRedirect started normalising routed paths that made every one of
  # these a 301 to a 301. Search Console had already caught the old spelling:
  # /blog/contract-checklist/ was reported as a duplicate with a Google-chosen
  # canonical, last crawled 2026-07-18 — a day before the rename shipped.
  OLD_BLOG_SLUGS = {
    "rrn-masking"        => "resident-number-masking",
    "contract-checklist" => "contract-sharing-checklist"
  }.freeze

  OLD_BLOG_SLUGS.each do |old_slug, new_slug|
    get "/blog/#{old_slug}", to: redirect("/blog/#{new_slug}")
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/#{old_slug}", to: redirect("/#{loc}/blog/#{new_slug}")
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

    # The blog index used to be a static file at public/blog/index.html, so
    # ActionDispatch::Static answered /blog, /blog/ AND /blog/index.html with an
    # identical 200 and Google indexed all three. 9f8bfff (2026-07-17) deleted
    # the file when the listing moved into Rails, which left /blog/index.html
    # falling through to "/blog/:slug" below as slug="index.html" → 404.
    # 301 it back onto the listing instead of stranding an indexed URL.
    # MUST stay above "/blog/:slug" — routes match in declaration order.
    get "/blog/index.html",
        to: redirect { |params, _req| params[:locale] ? "/#{params[:locale]}/blog" : "/blog" }

    get "/blog/:slug", to: "posts#show",  as: :blog_post
  end

  # SafeFile — public/safe/index.html은 Rails가 정적 서빙(언어 독립 단일 URL),
  # API는 AI 정밀 검사 중계. 로케일 프리픽스 없음.
  #
  # `get "/safe", to: redirect("/safe/")` 는 여기 있었지만 **한 번도 실행된 적이 없다**
  # (2026-09-17 제거). ActionDispatch::Static 이 라우터보다 앞에 있고,
  # FileHandler 가 `/safe` 요청을 `public/safe/index.html` 로 해석해 200 을 먼저
  # 돌려주기 때문이다. 트레일링 슬래시 정규화는 정적 핸들러보다 앞서야 하므로
  # Rack 미들웨어(lib/static_index_redirect.rb)로 옮겼다.
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
