Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :organizations, only: %i[index show], param: :siret
      resources :data_streams, param: :uuid
    end
  end
end
