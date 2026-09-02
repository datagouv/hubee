# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
    # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
    DEFAULT_STATE = "transmitted"

    def index
      # Pundit déduit la policy du nom de la classe : un modèle ActiveRecord n'est pas requis.
      @perimeter = policy_scope(Delivery)
      result = Deliveries::Index.call(
        membership: current_membership, perimeter: @perimeter,
        state: current_state, page: requested_page
      )

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
        skip_authorization
        (result.error == :not_found) ? not_found : unavailable
      end
    end

    private

    # L'état affiché, relu par la vue. `.to_s` : `?statut[]=…` fait de la valeur un tableau.
    # Aucune validation : l'amont tranche, et son refus est affiché plutôt que corrigé en douce.
    def current_state = @current_state ||= params[:statut].to_s.presence || DEFAULT_STATE

    # `.presence` : `?page=` vide retombe sur la première page. Une valeur trafiquée donne 0,
    # donc un décalage négatif que l'amont refuse.
    def requested_page = params[:page].to_s.presence&.to_i || 1
  end
end
