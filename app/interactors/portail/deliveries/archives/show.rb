# frozen_string_literal: true

module Portail
  module Deliveries
    module Archives
      class Show
        include Interactor::Organizer

        # Le télédossier est déjà autorisé par le contrôleur. En succès, `archive` est un Tempfile
        # que l'appelant supprime après l'envoi.
        organize Show::EnsureReceivedAttachments, Show::Download
      end
    end
  end
end
