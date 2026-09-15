# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      include Interactor::Organizer

      # La pièce est déjà autorisée par le contrôleur : il ne reste qu'à s'assurer qu'elle a un
      # contenu, sans réseau, puis à l'obtenir.
      organize Show::EnsureReceived, Show::FetchContent
    end
  end
end
