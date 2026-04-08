Rails.application.routes.draw do
  root "pages#home"

  resources :conversions, only: [:create, :show] do
    member do
      get :download
    end
  end

  post "/toggle_locale", to: "locales#toggle", as: :toggle_locale

  get "/compress", to: "pages#compress"
  get "/pdf",      to: "pages#pdf"
  get "/social",   to: "pages#social"
  get "/about",    to: "pages#about"
  get "/faq",      to: "pages#faq"

  get "/blog",       to: "posts#index", as: :blog
  get "/blog/:slug", to: "posts#show",  as: :blog_post

  namespace :admin do
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :posts do
      member do
        post :generate
        post :improve
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
