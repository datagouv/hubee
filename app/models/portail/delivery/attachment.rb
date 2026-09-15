# frozen_string_literal: true

module Portail
  class Delivery
    # L'inventaire d'une pièce, jamais son contenu, qui s'obtient par Portail::HubAPI::Attachments.
    # `state` compte : une pièce rejetée est une information que l'agent n'a nulle part ailleurs.
    # `filename` reste celui du déposant, brut : c'est la clé d'appariement de la lecture V1, par
    # égalité stricte. L'assainir appartient au seul point qui l'écrit dans un en-tête.
    Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state) do
      # Seul cet état a un contenu à remettre.
      def state_received? = state == "received"
    end
  end
end
