Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  # Pages d'erreur DSFR rendues par l'application (cf. config.exceptions_app = routes)
  match "/404", to: "portail/errors#not_found", via: :all
  match "/422", to: "portail/errors#unprocessable_entity", via: :all
  match "/500", to: "portail/errors#internal_server_error", via: :all

  # La page d'accueil du portail est servie à la racine de l'application.
  root "portail/dashboard#index"

  # =============================================================================
  # API V2 — GELÉE LE 2026-06-12
  #
  # L'API V2 est dépriorisée au profit du développement du portail V2
  # (repo datagouv/hubee), qui consomme l'API V1 via une gem cliente privée.
  #
  # Ces routes ne doivent PAS être réactivées pour corriger un bug :
  # le gel est intentionnel. La reprise du développement API V2 se fera
  # lorsque nécessaire, dans ce même repo.
  # =============================================================================
  #
  # namespace :api do
  #   namespace :v1 do
  #     resources :organizations, only: %i[index show] do
  #       resources :subscriptions, only: %i[index]
  #     end
  #
  #     resources :data_streams do
  #       resources :subscriptions, only: %i[index create]
  #       resources :data_packages, only: %i[index create]
  #     end
  #
  #     resources :subscriptions, only: %i[show update destroy], param: :id
  #
  #     resources :data_packages, only: %i[index show destroy], param: :id do
  #       resource :transmission, only: %i[create]
  #       resources :subscriptions, only: %i[index], controller: "data_packages/subscriptions"
  #     end
  #   end
  # end

  # Authentification ProConnect
  # La phase requête POST /auth/proconnect est interceptée par le middleware OmniAuth.
  get "auth/proconnect/callback", to: "portail/sessions#create"
  get "auth/failure", to: "portail/sessions#failure", as: :auth_failure
  # Le callback porte un code à usage unique : il redirige ici plutôt que de rendre le
  # refus, sinon la page ne serait ni rechargeable ni partageable.
  get "connexion/refusee", to: "portail/sessions#denied", as: :denied
  delete "logout", to: "portail/sessions#destroy", as: :logout
end
