# frozen_string_literal: true

module Portail
  # Le détail d'un télédossier. `attachments` ne porte que les pièces du dépôt initial, celles
  # apportées ensuite vivent sur leur event ; `all_attachments` réunit les deux.
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

    # Le dépôt d'abord : dans l'archive, ses pièces gardent leur nom face à une pièce ajoutée homonyme.
    def all_attachments = attachments + events.flat_map(&:attachments)

    def received_attachments = attachments.select(&:state_received?)

    # Ce que l'archive remet ; la garde de décision ne lit que `received_attachments`.
    def all_received_attachments = all_attachments.select(&:state_received?)

    # Une pièce par son identifiant, du dépôt ou apportée ensuite : l'événement qui la porte ne
    # regarde que la frontière amont.
    def find_attachment(id) = all_attachments.find { |attachment| attachment.id == id }

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
