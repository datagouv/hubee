# frozen_string_literal: true

module Portail
  class Subscription
    # Les identifiants du client OAuth d'un abonnement API. Le secret ne se lit que par son
    # accesseur : toute représentation textuelle le masque, parce qu'un objet finit tôt ou tard dans
    # un journal ou un rapport d'erreur.
    Credentials = Data.define(:client_id, :client_secret) do
      def inspect = "#<data #{self.class.name} client_id=#{client_id.inspect}, client_secret=\"[FILTERED]\">"

      def to_s = inspect

      def to_h = {client_id: client_id, client_secret: "[FILTERED]"}

      def pretty_print(printer) = printer.text(inspect)
    end
  end
end
