Rails.application.routes.draw do
  root "pages#index"

  # Gast-Flow (ohne Konto)
  resources :locations, only: :show
  resources :reservations, only: %i[new create show] do
    resource :cancellation, only: :create
  end
  resource :reservation_lookup, only: %i[new create]

  resources :users, only: %i[new create]
  resources :user_sessions, only: %i[new create destroy]

  # Mitarbeiter und Admins (Anmeldung nötig)
  namespace :staff do
    resources :activities, only: :index
    resources :reservations, only: %i[index show new create edit update] do
      resource :cancellation, only: :create
    end
  end

  # Nur Admins
  namespace :admin do
    root to: "dashboards#show", as: :dashboard
    resources :users, only: %i[index edit update]
    resources :locations, only: [] do
      resources :dining_tables, only: %i[index new create edit update]
    end
  end

  resource :profile, only: %i[show edit update]
  resource :password, only: %i[edit update]
  resource :email_change, only: %i[create]
  get "email_confirmations/:token", to: "email_confirmations#show", as: :email_confirmation

  get "up" => "rails/health#show", as: :rails_health_check
end