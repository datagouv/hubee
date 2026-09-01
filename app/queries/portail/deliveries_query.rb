# frozen_string_literal: true

module Portail
  # Traduit un rattachement et un périmètre déjà autorisé en demande de liste. La décision
  # d'autorisation appartient à Portail::DeliveryPolicy::Scope, que le contrôleur applique via
  # policy_scope ; le dialogue avec l'amont appartient à Portail::HubAPI. Ce query object porte
  # l'un et appelle l'autre, et reste le seul objet à savoir d'où viennent les démarches.
  class DeliveriesQuery
    PER_PAGE = 25

    # L'arrivée dans le périmètre de l'agent : ce qu'il n'a pas encore pris en charge. Ouvrir
    # sur un état terminal ferait d'une page d'accueil une archive. Appliqué par le contrôleur,
    # qui a besoin de l'état résolu pour la vue — et par lui seul.
    DEFAULT_STATE = "transmitted"

    # `client:` n'existe que pour l'injection en test — sur le chemin nominal, la gem gère
    # elle-même son jeton et son cache.
    def initialize(membership, client: nil)
      @membership = membership
      @client = client
    end

    # `state:` et `perimeter:` sont requis, sans valeur par défaut : le défaut d'un périmètre
    # serait forcément le plus large, et un appelant qui l'oublierait obtiendrait toute
    # l'organisation sans erreur ni trace.
    def call(state:, perimeter:, page: 1)
      # Un périmètre vide ne doit exiger ni appel, ni credentials — et surtout pas partir en
      # aval, où une liste de codes vide vaut « aucun filtre », donc tout le périmètre.
      return HubAPI::Deliveries.empty_list(per_page: PER_PAGE) if perimeter.none?

      HubAPI::Deliveries.list(
        # Le couple identifie l'organisation à lui seul et l'amont ne vérifie rien à notre
        # place : il vient du rattachement de l'agent authentifié, jamais d'un paramètre de
        # requête.
        siret: link.siret,
        insee_code: link.insee_code,
        state: state,
        data_stream_codes: perimeter.filter,
        page: page,
        per_page: PER_PAGE,
        client: @client
      )
    end

    def find(id:)
      HubAPI::Deliveries.find(
        id: id, siret: link.siret, insee_code: link.insee_code, client: @client
      )
    end

    private

    def link = @membership.organization_link
  end
end
