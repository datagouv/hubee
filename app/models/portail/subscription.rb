# frozen_string_literal: true

module Portail
  # L'abonnement d'une organisation à un flux, dans le modèle V2 : des permissions et un mode
  # d'accès, pas de statut. Le flux y est référencé par son code, comme sur un télédossier, et son
  # nom voyage à plat : l'amont ne le sert qu'avec l'abonnement. Homonyme de ::Subscription, le
  # modèle ActiveRecord : dans `module Portail`, un `Subscription` nu résout vers cette constante-ci.
  # L'abonnée est celle que l'amont a servie, confrontée au rattachement par la policy.
  class Subscription < Data.define(:id, :subscriber, :data_stream_code, :data_stream_name, :read_package, :create_package, :access_mode)
    PORTAL_ACCESS = "portal"
    API_ACCESS = "api"

    # Ce qui fait proposer un flux au filtre : l'organisation le reçoit, et par le portail.
    # L'amont ne sert pour l'heure que les dossiers de ces abonnements-là.
    def readable_via_portal? = read_package && access_mode == PORTAL_ACCESS

    # Le seul canal où un éditeur peut se connecter à la place de l'organisation.
    def api_access? = access_mode == API_ACCESS

    # Ce par quoi l'écran désigne le flux, comme data_stream_label : le code quand le nom manque.
    def data_stream_display_name = data_stream_name || data_stream_code
  end
end
