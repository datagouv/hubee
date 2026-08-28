# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    def index
      @state = requested_state
      return redirect_to demarches_path if @state.nil?

      # policy_scope depuis le contrôleur et non depuis le query object : c'est là que Pundit
      # rend la décision d'autorisation visible, et le seul endroit où un verify_policy_scoped
      # pourra l'exiger un jour. `policy_scope_class:` est explicite — la démarche est un objet
      # de la gem, dont Pundit ne saurait pas déduire la policy.
      codes = policy_scope(HubApiV1::V2::Delivery, policy_scope_class: DeliveryPolicy::Scope)
      # Retenu pour la vue : « aucun flux habilité » et « aucune démarche dans cet état » sont
      # deux situations qui appellent des actions différentes, et le tableau vide est le même.
      @no_habilitation = codes == []

      @result = DeliveriesQuery.new(current_membership)
        .call(state: @state, page: params[:page], data_stream_codes: codes)
    rescue HubApiV1::Client::Error => e
      render_degraded(e, t(".errors.unavailable"))
    end

    def show
      # Le périmètre vient du rattachement, jamais de l'URL : la gem ne vérifie rien à notre
      # place, elle borne la lecture au couple qu'on lui donne. Un périmètre étranger ne se
      # heurte à aucun refus en amont — il répond 200 avec les démarches de l'autre.
      #
      # `code_insee` côté gem, `insee_code` côté colonne : même donnée, deux graphies.
      link = current_membership.organization_link
      @delivery = HubApiV1::V2::Delivery.find(
        id: params[:id], siret: link.siret, code_insee: link.insee_code
      )
      # La gem borne sur l'organisation, pas sur les flux : sans cette ligne, un identifiant
      # connu ouvre une démarche hors habilitation que la liste ne montre pas.
      authorize @delivery, policy_class: DeliveryPolicy
    rescue Pundit::NotAuthorizedError, HubApiV1::V2::DeliveryNotFoundError
      # Refus et inexistence donnent le même message : les distinguer révélerait l'existence
      # de démarches hors du périmètre de l'agent. La gem confond déjà les trois causes
      # derrière DeliveryNotFoundError ; l'habilitation par flux reste la nôtre à refuser.
      redirect_to demarches_path, alert: t(".not_found")
    rescue HubApiV1::Client::Error
      redirect_to demarches_path, alert: t("portail.deliveries.index.errors.unavailable")
    end

    private

    # Le paramètre porte les états de la surcouche ; le français vit dans les libellés. Un
    # slug supplémentaire serait un endroit de plus où diverger.
    #
    # Comparaison de chaînes plutôt qu'un `to_sym` sur un paramètre d'URL : rien ne justifie
    # de convertir en symbole une entrée qu'on s'apprête de toute façon à valider.
    def requested_state
      return DeliveriesQuery::DEFAULT_STATE if params[:statut].blank?

      HubApiV1::V2::Mapping::ORDERED_STATES.find { |state| state.to_s == params[:statut] }
    end

    # La page se rend toujours : le portail dépend d'un service externe à chaque affichage, et
    # une indisponibilité doit laisser l'agent devant une explication, pas devant une page
    # d'erreur qui ne dit rien et n'offre rien.
    def render_degraded(exception, message)
      # Journalisé en plus d'être remonté : sans DSN Sentry — le cas en développement —
      # l'exception partirait au néant, et l'agent comme le développeur n'auraient que le
      # message générique de la page pour diagnostiquer.
      Rails.logger.error("Démarches indisponibles — #{exception.class} : #{exception.message}")
      Sentry.capture_exception(exception)
      @result = nil
      flash.now[:alert] = message
      render :index
    end
  end
end
