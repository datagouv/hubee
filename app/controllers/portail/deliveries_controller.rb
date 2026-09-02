# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    def index
      # Pundit déduit la policy du nom de la classe : un modèle ActiveRecord n'est pas requis.
      @perimeter = policy_scope(Delivery)
      result = Deliveries::Index.call(
        membership: current_membership, perimeter: @perimeter,
        # `.to_s` : `?statut[]=…` fait de la valeur un tableau. Aucune validation : l'amont
        # tranche, et son refus est affiché plutôt que corrigé en douce.
        state: params[:statut].to_s.presence,
        # `.presence` : `?page=` vide retombe sur la première page. Une valeur trafiquée donne
        # 0, donc un décalage négatif que l'amont refuse.
        page: params[:page].to_s.presence&.to_i
      )
      @state = result.state

      if result.success?
        @list = result.list
      elsif result.error == :no_habilitation
        render :no_habilitation
      else
        # Toujours 200 : le portail a servi sa page, c'est un service tiers qui manque.
        flash.now[:alert] = t("portail.deliveries.errors.#{result.error}")
        render :degraded
      end
    end

    def show
      result = Deliveries::Show.call(membership: current_membership, id: params[:id])

      if result.success?
        # L'amont borne sur l'organisation, pas sur les flux : sans cette ligne, un identifiant
        # connu ouvrirait une démarche hors habilitation.
        @delivery = authorize(result.delivery)
      else
        # Rien à autoriser : aucune démarche n'a été trouvée.
        skip_authorization
        (result.error == :not_found) ? not_found : unavailable
      end
    end
  end
end
