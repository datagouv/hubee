# frozen_string_literal: true

module Portail
  class Delivery
    # L'inventaire d'une pièce, jamais son contenu, qui s'obtient par Portail::HubAPI::Attachments.
    # `state` compte : une pièce rejetée est une information que l'agent n'a nulle part ailleurs.
    # `filename` reste celui du déposant, brut : c'est la clé d'appariement de la lecture V1, par
    # égalité stricte. L'assainir appartient au seul point qui l'écrit dans un en-tête.
    # `delivery` est la démarche dans l'inventaire de laquelle la pièce a été lue, en résumé : une
    # pièce ne se juge pas seule, et le résumé n'a pas de pièces, donc pas de cycle.
    Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state, :delivery) do
      # Seul cet état a un contenu : les autres restent consultables, mais ne se récupèrent pas.
      def received? = state == "received"
    end
  end
end
