Rails.application.routes.draw do
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

  get "up" => "rails/health#show", as: :rails_health_check
end
