# frozen_string_literal: true

module Portail
  # Les champs d'un rattachement dans la liste des agents, une méthode par champ avec son repli.
  module MembershipsHelper
    include Portail::DeliveriesHelper

    # Le nom de famille d'abord, comme le tri, et en capitales pour qu'on ne le prenne pas pour
    # un prénom. Les capitales ne valent qu'à l'affichage : la donnée garde sa casse.
    def membership_agent_name(membership)
      agent = membership.agent
      [agent.last_name&.upcase, agent.first_name].compact_blank.join(" ").presence || MISSING
    end

    # Sans repli : l'adresse est obligatoire, c'est elle qui résout l'agent à la connexion.
    def membership_email(membership) = membership.agent.email

    def membership_job_title(membership) = membership.job_title.presence || MISSING

    def membership_phone_number(membership) = membership.phone_number.presence || MISSING

    def membership_role(membership)
      tag.p(t("portail.memberships.roles.#{membership.role}"), class: "fr-badge fr-badge--sm")
    end

    def membership_last_signed_in_at(membership)
      return t("portail.memberships.never_signed_in") if membership.last_signed_in_at.nil?

      l(membership.last_signed_in_at, format: :long)
    end

    # La liste vide se lit selon le rôle, comme le périmètre réel : tout pour l'administrateur,
    # rien pour le membre. `subscribed_codes` nil : les abonnements n'ont pas pu être lus, et on
    # n'accuse pas une habilitation qu'on n'a pas vérifiée.
    def membership_data_streams(membership, names:, subscribed_codes:)
      return t("portail.memberships.data_streams.all") if Access::DataStreamPerimeter.unrestricted?(membership)
      return t("portail.memberships.data_streams.none") if Access::DataStreamPerimeter.none?(membership)

      labels = membership.data_stream_codes.to_h { |code| [code, data_stream_label(code, names[code])] }
      tag.ul(class: "fr-raw-list") do
        safe_join(labels.sort_by { |_code, label| I18n.transliterate(label).downcase }.map do |code, label|
          tag.li do
            safe_join([label, unsubscribed_badge(code, subscribed_codes)].compact, " ")
          end
        end)
      end
    end

    private

    def unsubscribed_badge(code, subscribed_codes)
      return if subscribed_codes.nil? || subscribed_codes.include?(code)

      tag.p(t("portail.memberships.data_streams.unsubscribed"), class: "fr-badge fr-badge--sm fr-badge--warning")
    end
  end
end
