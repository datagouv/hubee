Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  # =============================================================================
  # API V2 — GELÉE LE 2026-06-12
  #
  # L'API V2 est dépriorisée au profit du développement du portail V2
  # (repo datagouv/hubee), qui consomme l'API V1 via une gem cliente privée.
  #
  # Ces routes ne doivent PAS être réactivées pour corriger un bug :
  # le gel est intentionnel. La reprise du développement API V2 se fera
  # lorsque nécessaire, dans ce même repo.
  #
  # Contexte et décisions d'architecture (Notification vs Delivery,
  # can_read/can_write vs read_package/create_package, AASM vs boolean) :
  # voir "Registre des décisions" sur docs.numerique.gouv.fr
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
end
