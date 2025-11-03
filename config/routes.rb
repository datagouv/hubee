Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :organizations, only: %i[index show] do
        resources :subscriptions, only: %i[index]
      end

      resources :data_streams do
        resources :subscriptions, only: %i[index create]
        resources :data_packages, only: %i[index create]
      end

      resources :subscriptions, only: %i[show update destroy], param: :id

      resources :data_packages, only: %i[index show destroy], param: :id do
        resource :transmission, only: %i[create]
      end
    end
  end
end
