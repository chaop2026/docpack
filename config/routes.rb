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

  namespace :admin do
    get  "login",  to: "sessions#new",     as: :login
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :banners do
      member do
        patch :toggle
        patch :move
      end
    end

    root to: "banners#index"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
