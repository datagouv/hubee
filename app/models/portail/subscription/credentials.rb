# frozen_string_literal: true

module Portail
  class Subscription
    # Le secret n'est accepté qu'enveloppé : toute représentation le rend [FILTERED], et sa valeur ne
    # sort que par `reveal`, dans la seule vue qui le confie à la copie.
    Credentials = Data.define(:client_id, :client_secret) do
      def initialize(client_id:, client_secret:)
        raise TypeError, "client_secret must be a HubApiV1::Secret" unless client_secret.is_a?(HubApiV1::Secret)

        super
      end
    end
  end
end
