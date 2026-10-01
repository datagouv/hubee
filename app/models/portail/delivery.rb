# frozen_string_literal: true

module Portail
  # Le détail d'un télédossier. `attachments` ne porte que les pièces du dépôt initial, celles
  # apportées ensuite vivent sur leur event.
  Delivery = Data.define(
    :id, :number, :state, :data_stream_code, :recipient, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  ) do
    # `default:` : l'amont peut ajouter un état sans nous prévenir. `blank?` à part : I18n
    # résoudrait la clé tronquée vers son parent, le Hash entier des libellés.
    def self.state_label(state)
      return if state.blank?

      I18n.t("portail.deliveries.states.#{state}", default: nil)
    end

    def received_attachments = attachments.select(&:state_received?)

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
