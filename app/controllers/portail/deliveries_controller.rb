# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    def index
      @state = requested_state

      # policy_scope depuis le contrôleur et non depuis le query object : c'est là que Pundit
      # rend la décision d'autorisation visible, et le seul endroit où un verify_policy_scoped
      # pourra l'exiger un jour. `policy_scope_class:` est explicite — la démarche n'est pas un
      # modèle ActiveRecord, Pundit ne saurait pas déduire la policy.
      codes = policy_scope(Delivery, policy_scope_class: DeliveryPolicy::Scope)
      # Retenu pour la vue : « aucun flux habilité » et « aucune démarche dans cet état » sont
      # deux situations qui appellent des actions différentes, et le tableau vide est le même.
      @no_habilitation = codes == []

      @result = DeliveriesQuery.new(current_membership)
        .call(state: @state, page: params.fetch(:page, 1), data_stream_codes: codes)
    rescue HubAPI::InvalidRequest => e
      render_refusal(e, t(".errors.invalid_request"))
    rescue HubAPI::Error => e
      render_degraded(e, t(".errors.unavailable"))
    end

    def show
      # Le périmètre vient du rattachement, jamais de l'URL : l'amont ne vérifie rien à notre
      # place, il borne la lecture au couple qu'on lui donne. Un périmètre étranger ne se
      # heurte à aucun refus — il répond avec les démarches de l'autre.
      link = current_membership.organization_link
      @delivery = HubAPI::Deliveries.find(
        id: params[:id], siret: link.siret, insee_code: link.insee_code
      )
      # L'amont borne sur l'organisation, pas sur les flux : sans cette ligne, un identifiant
      # connu ouvre une démarche hors habilitation que la liste ne montre pas.
      authorize @delivery, policy_class: DeliveryPolicy
    rescue Pundit::NotAuthorizedError, HubAPI::NotFound
      # Refus et inexistence donnent le même message : les distinguer révélerait l'existence
      # de démarches hors du périmètre de l'agent. L'habilitation par flux reste la nôtre à
      # refuser, la traduction confond déjà les autres causes.
      redirect_to demarches_path, alert: t(".not_found")
    rescue HubAPI::Error
      redirect_to demarches_path, alert: t("portail.deliveries.index.errors.unavailable")
    end

    private

    # Le paramètre porte les états de l'amont ; le français vit dans les libellés. Un slug
    # supplémentaire serait un endroit de plus où diverger.
    #
    # Aucune validation ici : c'est l'amont qui tranche, et son refus revient traduit en
    # HubAPI::InvalidRequest. Un état inconnu produit donc une erreur affichée, jamais un
    # filtre réinitialisé en douce sur une liste qui ne dirait pas ce qu'elle montre.
    def requested_state = params[:statut].presence || DeliveriesQuery::DEFAULT_STATE

    # Une indisponibilité de l'amont est un incident : elle part en alerte.
    def render_degraded(exception, message)
      # Journalisé en plus d'être remonté : sans DSN Sentry — le cas en développement —
      # l'exception partirait au néant, et l'agent comme le développeur n'auraient que le
      # message générique de la page pour diagnostiquer.
      Rails.logger.error("Démarches indisponibles — #{exception.class} : #{exception.message}")
      Sentry.capture_exception(exception)
      render_alert(message)
    end

    # Un paramètre que l'amont refuse est un fait, pas un incident : il se journalise pour le
    # diagnostic mais ne part pas en alerte — un robot qui balaie des URL suffirait sinon à
    # noyer Sentry sous des refus parfaitement normaux.
    def render_refusal(exception, message)
      Rails.logger.info("Filtre de démarches refusé — #{exception.message}")
      render_alert(message)
    end

    # La page se rend toujours : le portail dépend d'un service externe à chaque affichage, et
    # un refus comme une panne doivent laisser l'agent devant une explication, pas devant une
    # page d'erreur qui ne dit rien et n'offre rien.
    def render_alert(message)
      @result = nil
      flash.now[:alert] = message
      render :index
    end
  end
end
