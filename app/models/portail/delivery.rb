# frozen_string_literal: true

module Portail
  # Le détail d'un télédossier. `attachments` ne porte que les pièces du dépôt initial, celles
  # apportées ensuite vivent sur leur event.
  Delivery = Data.define(
    :id, :number, :state, :data_stream_code, :recipient, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  ) do
    def received_attachments = attachments.select(&:state_received?)

    # Une pièce par son identifiant, du dépôt ou apportée ensuite : l'événement qui la porte ne
    # regarde que la frontière amont.
    def find_attachment(id)
      attachments.find { |attachment| attachment.id == id } ||
        events.flat_map(&:attachments).find { |attachment| attachment.id == id }
    end

    # Tout auteur, toute pièce : une seule récupération prouve la lecture.
    def retrieved?
      events.any? { |event| event.event_type.in?(%w[attachment.downloaded attachment.all_downloaded]) }
    end

    # Paris explicitement, indépendamment du fuseau de l'application.
    def archive_filename
      "#{Time.current.in_time_zone("Europe/Paris").strftime("%Y%m%d-%H.%M")}_#{SafeFilename.for(number)}.zip"
    end
  end
end
