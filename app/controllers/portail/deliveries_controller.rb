# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    rescue_from Pundit::NotAuthorizedError, with: :refuse_out_of_perimeter

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
        redirect_to demarches_path, alert: t("portail.deliveries.errors.#{result.error}")
      end
    end

    private

    # Même message qu'une démarche inexistante : distinguer révélerait l'existence d'une
    # démarche hors périmètre. Journalisé sans alerte : un refus qui fonctionne n'est pas une
    # panne. `inspect` : l'identifiant vient de l'URL.
    def refuse_out_of_perimeter
      Rails.logger.warn("Démarche refusée — hors habilitation : #{params[:id].inspect}")
      redirect_to demarches_path, alert: t("portail.deliveries.errors.not_found")
    end
  end
end
