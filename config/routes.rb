Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :organizations, only: %i[index show] do
        resources :subscriptions, only: [:index]
      end

      resources :data_streams do
        resources :subscriptions, only: [:index, :create]
      end

      resources :subscriptions, only: [:show, :update, :destroy], param: :id
    end
  end
end
