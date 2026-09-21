Rails.application.routes.draw do
  root "pages#index"

  resources :users, only: %i[new create]
  resources :user_sessions, only: %i[new create destroy]

  namespace :admin do
    root to: "dashboards#show", as: :dashboard
    resources :users, only: %i[index edit update]
  end

  resource :profile, only: %i[show edit update]
  resource :password, only: %i[edit update]
  resource :email_change, only: %i[create]
  get "email_confirmations/:token", to: "email_confirmations#show", as: :email_confirmation

  get "up" => "rails/health#show", as: :rails_health_check
end