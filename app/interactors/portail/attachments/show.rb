# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      include Interactor::Organizer

      # La pièce d'abord, sans réseau : rien ne part vers l'amont pour une pièce non livrable.
      # Le contenu est contrôlé avant tout ce qui viendrait après lui.
      organize Show::LocateAttachment, Show::FetchContent, Show::VerifyContentSize
    end
  end
end
