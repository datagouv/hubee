# frozen_string_literal: true

module Portail
  # L'historique d'un télédossier, servi seul pour que la page ouverte puisse le rafraîchir après
  # une récupération de pièce. Même lecture et même garde que le détail : un fragment moins gardé
  # que sa page servirait l'historique d'un télédossier que l'agent n'a pas le droit d'ouvrir.
  class HistoriesController < Portail::BaseController
    def show
      result = Deliveries::Show.call(membership: current_membership, id: params[:teledossier_id])

      unless result.success?
        skip_authorization
        return (result.error == :not_found) ? not_found : unavailable
      end

      @delivery = authorize(result.delivery, :show?)
    end
  end
end
