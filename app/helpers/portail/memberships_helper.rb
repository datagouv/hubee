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
    # rien pour le membre. « Tous les flux » est une règle et non une liste : elle vaut aussi pour
    # les abonnements à venir, et le lien vers les abonnements dit lesquels. `subscribed_codes`
    # nil : les abonnements n'ont pas pu être lus, et on n'accuse pas une habilitation qu'on n'a
    # pas vérifiée. Des tags au nom seul : une douzaine passent à la ligne dans la cellule au lieu
    # d'étirer la ligne, et les flux se répètent d'un agent à l'autre.
    def membership_data_streams(membership, names:, subscribed_codes:)
      if Access::DataStreamPerimeter.unrestricted?(membership)
        return link_to(t("portail.memberships.data_streams.all"), abonnements_path,
          class: "fr-link fr-link--sm", aria: {label: t("portail.memberships.data_streams.all_label")})
      end
      return t("portail.memberships.data_streams.none") if Access::DataStreamPerimeter.none?(membership)

      codes = membership.data_stream_codes.sort_by { |code| I18n.transliterate(data_stream_name(code, names[code])).downcase }
      tag.ul(class: "fr-tags-group fr-tags-group--sm membership-data-streams") do
        safe_join(codes.map { |code| tag.li(data_stream_tag(data_stream_name(code, names[code]), code, subscribed_codes)) })
      end
    end

    private

    # Hors abonnement, le tag lui-même change d'allure : un badge à côté se perdait parmi douze
    # tags. Le texte le dit aussi, la couleur seule ne suffit pas.
    def data_stream_tag(name, code, subscribed_codes)
      return tag.p(name, class: "fr-tag") if subscribed_codes.nil? || subscribed_codes.include?(code)

      tag.p(t("portail.memberships.data_streams.unsubscribed", name:),
        class: "fr-tag fr-tag--icon-left fr-icon-warning-fill membership-data-streams__unsubscribed")
    end
  end
end
