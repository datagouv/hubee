# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    # Le garde-fou vit ici et non sur BaseController : `SessionsController#authorize` est une
    # action qui masque la méthode de Pundit, et aucun autre contrôleur du portail ne porte
    # encore de policy. Il remonte le jour où un second en porte une.
    #
    # `except:` et non `only:` : une action ajoutée demain est couverte par les deux gardes, et
    # doit se déclarer collection ou unitaire pour en sortir. Un `only:` la laisserait passer
    # sans autorisation ni périmètre, en silence.
    after_action :verify_authorized, except: :index
    after_action :verify_policy_scoped, except: :show

    def index
      @state = requested_state
      # Pundit déduit Portail::DeliveryPolicy::Scope du nom de la classe : il lui suffit d'une
      # classe, un modèle ActiveRecord n'est pas requis.
      @perimeter = policy_scope(Delivery)
      @result = fetch_list
      @page_state = resolve_page_state
    end

    def show
      @delivery = fetch_delivery
      return if performed?

      # L'amont borne sur l'organisation, pas sur les flux : sans cette ligne, un identifiant
      # connu ouvre une démarche hors habilitation que la liste ne montre pas.
      authorize @delivery
    rescue Pundit::NotAuthorizedError
      # Un refus d'habilitation se journalise mais ne part pas en alerte : c'est un refus qui
      # fonctionne, pas une panne. `inspect` : l'identifiant vient de l'URL, des retours à la
      # ligne y forgeraient de fausses lignes de journal.
      Rails.logger.warn("Démarche refusée — hors habilitation : #{params[:id].inspect}")
      redirect_to_list_with_not_found
    end

    private

    # Le rescue tient à l'appel amont, seul à pouvoir lever ces erreurs.
    def fetch_list
      DeliveriesQuery.new(current_membership)
        .call(state: @state, perimeter: @perimeter, page: requested_page)
    rescue HubAPI::InvalidRequest => e
      # Un paramètre que l'amont refuse est un fait, pas un incident : il se journalise mais ne
      # part pas en alerte — un robot qui balaie des URL noierait Sentry sous des refus normaux.
      # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
      Rails.logger.info("Filtre de démarches refusé — #{e.message.inspect}")
      degrade(t("portail.deliveries.errors.invalid_request"))
    rescue HubAPI::Error => e
      report_outage(e)
      degrade(t("portail.deliveries.errors.unavailable"))
    end

    # Redirige lui-même ; l'action s'arrête sur `performed?`. `skip_authorization` dit au
    # garde-fou que rien n'a été autorisé faute de démarche à autoriser — sans lui, une
    # démarche introuvable lèverait AuthorizationNotPerformedError.
    def fetch_delivery
      DeliveriesQuery.new(current_membership).find(id: params[:id])
    rescue HubAPI::NotFound
      # Refus et inexistence donnent le même message : les distinguer révélerait l'existence de
      # démarches hors du périmètre de l'agent. Ils restent distincts au journal.
      Rails.logger.info("Démarche introuvable en amont : #{params[:id].inspect}")
      skip_authorization
      redirect_to_list_with_not_found
    rescue HubAPI::Error => e
      # `InvalidRequest` est rangé ici avec les pannes : au détail, un paramètre refusé ne peut
      # venir que du couple qui borne le périmètre, donc de nos données et non de l'URL.
      report_outage(e)
      skip_authorization
      redirect_to demarches_path, alert: t("portail.deliveries.errors.unavailable")
    end

    # L'état de la page, résolu ici et pas déduit d'un `nil` dans le gabarit. « Aucun flux
    # habilité » et « aucune démarche dans cet état » appellent des actions différentes, et le
    # tableau vide est le même.
    def resolve_page_state
      return :degraded if @result.nil?
      return :no_habilitation if @perimeter.none?

      @result.deliveries.empty? ? :empty : :results
    end

    # Le paramètre porte les états de l'amont ; le français vit dans les libellés. Aucune
    # validation ici : c'est l'amont qui tranche, et son refus revient traduit en
    # HubAPI::InvalidRequest — un état inconnu produit une erreur affichée, jamais un filtre
    # réinitialisé en douce. `.to_s` d'abord : `?statut[]=…` fait de la valeur un tableau.
    def requested_state = params[:statut].to_s.presence || DeliveriesQuery::DEFAULT_STATE

    # Un entier, toujours. `.presence` et non `fetch` : avec `?page=`, la clé existe et vaut la
    # chaîne vide, qui retombe sur la première page comme un champ de formulaire laissé vide.
    # Une valeur trafiquée donne 0, donc un décalage négatif, que l'amont refuse.
    def requested_page = params[:page].to_s.presence&.to_i || 1

    def redirect_to_list_with_not_found
      redirect_to demarches_path, alert: t("portail.deliveries.show.not_found")
    end

    # Une indisponibilité de l'amont est un incident : elle part en alerte. Journalisée en plus
    # d'être remontée : sans DSN Sentry — le cas en développement — l'exception partirait au
    # néant.
    def report_outage(exception)
      Rails.logger.error("Démarches indisponibles — #{exception.class} : #{exception.message}")
      Sentry.capture_exception(exception)
    end

    # La page se rend toujours, et en 200 : le portail a servi sa page, c'est un service tiers
    # qui est indisponible. Ce qui rend l'incident visible, c'est `report_outage`, pas le code
    # de statut.
    def degrade(message)
      flash.now[:alert] = message
      nil
    end
  end
end
