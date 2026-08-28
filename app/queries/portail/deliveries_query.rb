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
      return HubApiV1::V2::DeliveryList.empty(per_page: PER_PAGE) if data_stream_codes == []

      options = {
        # Le couple identifie l'organisation à lui seul : la gem ne consulte plus le
        # référentiel et ne vérifie rien : elle liste ce périmètre-là. Il vient donc du
        # rattachement de l'agent authentifié, jamais d'un paramètre de requête.
        #
        # `code_insee` côté gem, `insee_code` côté colonne : même donnée, deux graphies.
        siret: link.siret,
        code_insee: link.insee_code,
        state: state,
        data_stream_codes: data_stream_codes || [],
        offset: offset_for(page),
        per_page: PER_PAGE
      }
      # `client:` n'est transmis que s'il a été injecté. Le passer inconditionnellement
      # obligerait à résoudre `HubApiV1.client` ici, dans l'expression d'argument — donc
      # avant l'appel, et même lorsque `list` est bouchonné en spec, où aucune variable
      # d'environnement n'est posée. Absent, c'est la gem qui résout le sien, à l'intérieur.
      options[:client] = @client if @client

      HubApiV1::V2::Delivery.list(**options)
    end

    private

    def link = @membership.organization_link

    # `to_i` sur un paramètre d'URL absent ou trafiqué donne 0 ; le plancher à 1 évite un
    # décalage négatif, que l'API amont rejetterait en erreur plutôt qu'en première page.
    def offset_for(page) = ([page.to_i, 1].max - 1) * PER_PAGE
  end
end
