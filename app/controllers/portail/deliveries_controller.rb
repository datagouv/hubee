# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    rescue_from Pundit::NotAuthorizedError, with: :refuse_out_of_perimeter

    def index
      @state = requested_state
      # Pundit déduit la policy du nom de la classe : un modèle ActiveRecord n'est pas requis.
      @perimeter = policy_scope(Delivery)
      @result = fetch_list
      @page_state = resolve_page_state
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

    def fetch_list
      DeliveriesQuery.new(current_membership)
        .call(state: @state, perimeter: @perimeter, page: requested_page)
    rescue HubAPI::InvalidRequest => e
      # Sans alerte : un robot qui balaie des URL noierait Sentry sous des refus normaux.
      # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
      Rails.logger.info("Filtre de démarches refusé — #{e.message.inspect}")
      degrade(t("portail.deliveries.errors.invalid_request"))
    rescue HubAPI::Error => e
      report_outage(e)
      degrade(t("portail.deliveries.errors.unavailable"))
    end

    # Résolu ici et non déduit d'un `nil` dans le gabarit : « aucun flux habilité » et « aucune
    # démarche » appellent des actions différentes pour le même tableau vide.
    def resolve_page_state
      return :degraded if @result.nil?
      return :no_habilitation if @perimeter.none?

      @result.deliveries.empty? ? :empty : :results
    end

    # Aucune validation : l'amont tranche, et son refus revient en InvalidRequest, affiché
    # plutôt que corrigé en douce. `.to_s` : `?statut[]=…` fait de la valeur un tableau.
    def requested_state = params[:statut].to_s.presence || DeliveriesQuery::DEFAULT_STATE

    # `.presence` : `?page=` vide retombe sur la première page. Une valeur trafiquée donne 0,
    # donc un décalage négatif que l'amont refuse.
    def requested_page = params[:page].to_s.presence&.to_i || 1

    # Même message qu'une démarche inexistante : distinguer révélerait l'existence d'une
    # démarche hors périmètre. Journalisé sans alerte : un refus qui fonctionne n'est pas une
    # panne. `inspect` : l'identifiant vient de l'URL.
    def refuse_out_of_perimeter
      Rails.logger.warn("Démarche refusée — hors habilitation : #{params[:id].inspect}")
      redirect_to demarches_path, alert: t("portail.deliveries.errors.not_found")
    end

    # Journalisée en plus de Sentry : sans DSN, en développement, l'exception partirait au néant.
    def report_outage(exception)
      Rails.logger.error("Démarches indisponibles — #{exception.class} : #{exception.message}")
      Sentry.capture_exception(exception)
    end

    # Toujours 200 : le portail a servi sa page, c'est un service tiers qui manque. L'incident
    # est rendu visible par `report_outage`, pas par le statut.
    def degrade(message)
      flash.now[:alert] = message
      nil
    end
  end
end
