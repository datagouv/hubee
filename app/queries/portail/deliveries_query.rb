# frozen_string_literal: true

module Portail
  # Traduit un rattachement et un périmètre déjà autorisé en demande de liste. La décision
  # d'autorisation ne se prend pas ici : elle appartient à Portail::DeliveryPolicy::Scope,
  # que le contrôleur applique via policy_scope. Ce query object ne fait que la porter.
  #
  # Le dialogue avec l'amont ne se fait pas ici non plus : il appartient à Portail::HubAPI.
  class DeliveriesQuery
    PER_PAGE = 25

    # L'arrivée dans le périmètre de l'agent : ce qu'il n'a pas encore pris en charge.
    # Ouvrir sur un état terminal ferait d'une page d'accueil une archive.
    DEFAULT_STATE = "transmitted"

    # `client:` n'existe que pour l'injection en test — sur le chemin nominal, la gem gère
    # elle-même son jeton et son cache.
    def initialize(membership, client: nil)
      @membership = membership
      @client = client
    end

    # `data_stream_codes` vient de la policy : nil pour aucun filtre, une liste de codes
    # pour borner, un tableau vide pour aucun accès.
    def call(state: DEFAULT_STATE, page: 1, data_stream_codes: nil)
      # Comparaison à [] plutôt qu'un `empty?` : nil et [] sont les deux valeurs qui se
      # ressemblent et signifient l'inverse. Un tableau vide transmis en aval vaudrait
      # « aucun filtre », donc tout le périmètre de l'organisation — on court-circuite
      # avant l'appel plutôt que de le laisser fuir.
      return HubAPI::Deliveries.empty_list(per_page: PER_PAGE) if data_stream_codes == []

      HubAPI::Deliveries.list(
        # Le couple identifie l'organisation à lui seul et l'amont ne vérifie rien à notre
        # place : il vient du rattachement de l'agent authentifié, jamais d'un paramètre de
        # requête.
        siret: link.siret,
        insee_code: link.insee_code,
        state: state,
        data_stream_codes: data_stream_codes || [],
        page: page,
        per_page: PER_PAGE,
        client: @client
      )
    end

    private

    def link = @membership.organization_link
  end
end
