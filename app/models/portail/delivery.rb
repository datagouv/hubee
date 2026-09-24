# frozen_string_literal: true

module Portail
  # Le détail d'un télédossier. `attachments` ne porte que les pièces du dépôt initial, celles
  # apportées ensuite vivent sur leur event.
  Delivery = Data.define(
    :id, :number, :state, :data_stream_code, :recipient, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  ) do
    def received_attachments = attachments.select(&:state_received?)

    # Paris explicitement, indépendamment du fuseau de l'application.
    def archive_filename
      "#{Time.current.in_time_zone("Europe/Paris").strftime("%Y%m%d-%H.%M")}_#{SafeFilename.for(number)}.zip"
    end
  end
end
