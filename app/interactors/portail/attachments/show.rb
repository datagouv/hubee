# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      include Interactor::Organizer

      # La pièce est déjà autorisée par le contrôleur. Rien ne part vers l'amont pour une pièce
      # sans contenu.
      organize Show::EnsureReceivedState, Show::FetchContent
    end
  end
end
