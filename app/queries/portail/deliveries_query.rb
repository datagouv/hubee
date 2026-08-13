# frozen_string_literal: true

# Un des deux seuls points du dépôt qui requièrent la gem, avec l'initializer qui la
# configure. Elle vit dans un groupe hors `default`, que `Bundler.require(*Rails.groups)`
# n'inclut pas : elle n'est donc jamais auto-requise, et il faut la demander explicitement
# là où on la consomme.
require "hub_api_v1"

module Portail
  # Traduit un rattachement et un périmètre déjà autorisé en appel de liste. La décision
  # d'autorisation ne se prend pas ici : elle appartient à Portail::DeliveryPolicy::Scope,
  # que le contrôleur applique via policy_scope. Ce query object ne fait que la porter.
  class DeliveriesQuery
    PER_PAGE = 25

    # L'arrivée dans le périmètre de l'agent : ce qu'il n'a pas encore pris en charge.
    # Ouvrir sur un état terminal ferait d'une page d'accueil une archive.
    DEFAULT_STATE = :transmitted

    # `client:` n'existe que pour l'injection en test — sur le chemin nominal, la gem gère
    # elle-même son jeton et son cache, et on ne le lui transmet pas du tout (cf. #call).
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
      return empty_result if data_stream_codes == []

      options = {
        siret: @membership.organization_link.siret,
        state: state,
        data_stream_codes: data_stream_codes || [],
        offset: offset_for(page),
        per_page: PER_PAGE,
        # Deux scopes parce que deux routes : la surcouche résout d'abord le périmètre auprès
        # du référentiel, puis liste les téléservices, et l'API amont ne les ouvre pas aux
        # mêmes. Les valeurs sont les nôtres — la gem ne fait que les transmettre.
        referential_scope: HubAPIScopes.referential,
        teleservices_scope: HubAPIScopes.teleservices
      }
      # `client:` n'est transmis que s'il a été injecté. Le passer inconditionnellement
      # obligerait à résoudre `HubApiV1.client` ici, dans l'expression d'argument — donc
      # avant l'appel, et même lorsque `list` est bouchonné en spec, où aucune variable
      # d'environnement n'est posée. Absent, c'est la gem qui résout le sien, à l'intérieur.
      options[:client] = @client if @client

      HubApiV1::V2::Delivery.list(**options)
    end

    private

    # `to_i` sur un paramètre d'URL absent ou trafiqué donne 0 ; le plancher à 1 évite un
    # décalage négatif, que l'API amont rejetterait en erreur plutôt qu'en première page.
    def offset_for(page) = ([page.to_i, 1].max - 1) * PER_PAGE

    def empty_result
      HubApiV1::V2::DeliveryList.new(
        deliveries: [],
        pagination: HubApiV1::PaginatedResult.new(
          records: [], total: 0, offset: 0, per_page: PER_PAGE
        ).metadata,
        counts_by_state: HubApiV1::V2::Mapping::ORDERED_STATES.to_h { |state| [state, 0] }
      )
    end
  end
end
