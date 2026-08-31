# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    def index
      @state = requested_state

      # policy_scope depuis le contrôleur et non depuis le query object : c'est là que Pundit
      # rend la décision d'autorisation visible, et le seul endroit où un verify_policy_scoped
      # pourra l'exiger un jour. `policy_scope_class:` est explicite — la démarche n'est pas un
      # modèle ActiveRecord, Pundit ne saurait pas déduire la policy.
      #
      # Retenu pour la vue : « aucun flux habilité » et « aucune démarche dans cet état » sont
      # deux situations qui appellent des actions différentes, et le tableau vide est le même.
      @perimeter = policy_scope(Delivery, policy_scope_class: DeliveryPolicy::Scope)

      @result = DeliveriesQuery.new(current_membership)
        .call(state: @state, perimeter: @perimeter, page: requested_page)
    rescue HubAPI::InvalidRequest => e
      render_refusal(e, t("portail.deliveries.errors.invalid_request"))
    rescue HubAPI::Error => e
      render_degraded(e, t("portail.deliveries.errors.unavailable"))
    end

    def show
      # Le périmètre vient du rattachement, jamais de l'URL : l'amont ne vérifie rien à notre
      # place, il borne la lecture au couple qu'on lui donne. Un périmètre étranger ne se
      # heurte à aucun refus — il répond avec les démarches de l'autre.
      @delivery = DeliveriesQuery.new(current_membership).find(id: params[:id])
      # L'amont borne sur l'organisation, pas sur les flux : sans cette ligne, un identifiant
      # connu ouvre une démarche hors habilitation que la liste ne montre pas.
      authorize @delivery, policy_class: DeliveryPolicy
    rescue Pundit::NotAuthorizedError
      # Un agent qui atteint une démarche hors de son périmètre est un fait de sécurité : il se
      # journalise, mais ne part pas en alerte — c'est un refus qui fonctionne, pas une panne.
      Rails.logger.warn("Démarche refusée — hors habilitation : #{params[:id]}")
      redirect_to_list_with_not_found
    rescue HubAPI::NotFound
      # Refus et inexistence donnent le même message : les distinguer révélerait l'existence
      # de démarches hors du périmètre de l'agent. Ils restent distincts au journal, où seul
      # l'exploitant les lit.
      Rails.logger.info("Démarche introuvable en amont : #{params[:id]}")
      redirect_to_list_with_not_found
    rescue HubAPI::Error => e
      # `InvalidRequest` est rangé ici avec les pannes, et non montré comme sur la liste : au
      # détail, un paramètre refusé ne peut venir que du couple qui borne le périmètre — donc de
      # nos données, pas de l'URL. L'agent n'y peut rien, c'est bien une indisponibilité.
      report_outage(e)
      redirect_to demarches_path, alert: t("portail.deliveries.errors.unavailable")
    end

    private

    # Le paramètre porte les états de l'amont ; le français vit dans les libellés. Un slug
    # supplémentaire serait un endroit de plus où diverger.
    #
    # Aucune validation ici : c'est l'amont qui tranche, et son refus revient traduit en
    # HubAPI::InvalidRequest. Un état inconnu produit donc une erreur affichée, jamais un
    # filtre réinitialisé en douce sur une liste qui ne dirait pas ce qu'elle montre.
    def requested_state = params[:statut].presence || DeliveriesQuery::DEFAULT_STATE

    # `.presence` et non `fetch` : avec `?page=`, la clé existe et vaut la chaîne vide, dont le
    # `to_i` donne un décalage négatif que l'amont refuse. Une chaîne vide n'est pas un
    # paramètre trafiqué, c'est ce qu'un formulaire soumet avec un champ vide — elle retombe
    # sur la première page comme `statut` retombe sur son défaut. Une valeur réellement
    # trafiquée, elle, continue d'aller se faire refuser en amont.
    def requested_page = params[:page].presence || 1

    def redirect_to_list_with_not_found
      redirect_to demarches_path, alert: t("portail.deliveries.show.not_found")
    end

    # Une indisponibilité de l'amont est un incident : elle part en alerte. Journalisée en plus
    # d'être remontée : sans DSN Sentry — le cas en développement — l'exception partirait au
    # néant, et l'agent comme le développeur n'auraient que le message générique de la page
    # pour diagnostiquer.
    def report_outage(exception)
      Rails.logger.error("Démarches indisponibles — #{exception.class} : #{exception.message}")
      Sentry.capture_exception(exception)
    end

    def render_degraded(exception, message)
      report_outage(exception)
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
    #
    # Et elle se rend en 200, délibérément. Le code de statut décrit CETTE réponse : le portail
    # a servi sa page, il n'est pas indisponible — c'est un service tiers qui l'est, et c'est à
    # lui d'être supervisé de son côté. Un 503 ferait sonner l'astreinte du portail pour une
    # panne qu'il ne possède pas. Ce qui rend l'incident visible, c'est `report_outage`, pas le
    # statut. (La seule objection sérieuse, une page dégradée mise en cache puis resservie après
    # rétablissement, est déjà fermée par le `no-store` de BaseController.)
    def render_alert(message)
      @result = nil
      flash.now[:alert] = message
      render :index
    end
  end
end
