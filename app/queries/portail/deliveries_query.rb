# frozen_string_literal: true

module Portail
  # Traduit un rattachement et un périmètre déjà autorisé en demande de liste. L'autorisation
  # appartient à la policy, le dialogue avec l'amont à Portail::HubAPI.
  class DeliveriesQuery
    PER_PAGE = 25

    # Ce que l'agent n'a pas encore pris en charge : ouvrir sur un état terminal ferait d'une
    # page d'accueil une archive.
    DEFAULT_STATE = "transmitted"

    # `client:` n'existe que pour l'injection en test.
    def initialize(membership, client: nil)
      @membership = membership
      @client = client
    end

    # `perimeter:` sans défaut : le défaut serait forcément le plus large, et un oubli
    # ouvrirait toute l'organisation sans erreur ni trace.
    def call(state:, perimeter:, page: 1)
      # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut « aucun filtre ».
      return HubAPI::Deliveries.empty_list(per_page: PER_PAGE) if perimeter.none?

      HubAPI::Deliveries.list(
        # Le couple vient du rattachement authentifié, jamais d'un paramètre de requête :
        # l'amont ne vérifie rien à notre place.
        siret: link.siret,
        insee_code: link.insee_code,
        state: state,
        data_stream_codes: perimeter.filter,
        page: page,
        per_page: PER_PAGE,
        client: @client
      )
    end

    private

    def link = @membership.organization_link
  end
end
