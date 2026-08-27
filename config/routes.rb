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

  # API V2 — authentification des systèmes clients. Flux client_credentials
  # seul : pas d'écrans d'autorisation ni de gestion.
  use_doorkeeper scope: "api/oauth" do
    skip_controllers :authorizations, :applications, :authorized_applications
  end

  namespace :api do
    get "ping", to: "pings#show"
  end

  # Authentification ProConnect
  # En POST : le départ est couvert par le jeton CSRF de Rails.
  post "connexion/proconnect", to: "portail/sessions#authorize", as: :proconnect_authorization
  # Doit correspondre au redirect_uri déclaré auprès de ProConnect (env + espace
  # partenaires) : les deux se changent ensemble.
  get "connexion/proconnect/retour", to: "portail/sessions#create", as: :proconnect_callback
  get "connexion/echec", to: "portail/sessions#failure", as: :auth_failure
  # Leurs propres adresses, hors du callback : son code à usage unique rendrait ces pages
  # irrechargeables — ProConnect répond 400 sur un code rejoué.
  get "connexion/refusee", to: "portail/sessions#denied", as: :denied
  get "connexion/second-facteur", to: "portail/sessions#step_up", as: :step_up
  delete "logout", to: "portail/sessions#destroy", as: :logout
end
