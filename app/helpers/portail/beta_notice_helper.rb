# frozen_string_literal: true

module Portail
  # Le bandeau de la bêta et ses mails pré-remplis, qui portent au support le contexte de l'agent.
  module BetaNoticeHelper
    BETA_EMAIL = "hubee.portail.pilote@numerique.gouv.fr"

    # Affiché sauf coupure explicite : la fin de la bêta n'attend pas une livraison de code.
    def beta_notice? = ENV["HIDE_BETA_NOTICE"] != "true"

    # Retours à la ligne en CRLF, seuls reconnus par tous les clients mail (RFC 6068).
    def beta_mail_to(kind, membership:, page_url:)
      scope = "portail.shared.beta_notice"
      siret = membership&.organization_link&.siret
      subject = [t("#{scope}.#{kind}.subject"), (t("#{scope}.subject_siret", siret:) if siret)].compact.join(" - ")
      context = []
      if membership
        agent = membership.agent
        name = [agent.first_name, agent.last_name&.upcase].compact_blank.join(" ")
        context << t("#{scope}.context.agent", name:, email: agent.email)
        context << t("#{scope}.context.siret", siret:)
      end
      context << t("#{scope}.context.page", url: page_url)
      body = [t("#{scope}.#{kind}.prompt"), "", "", "", "---", *context].join("\r\n")

      mail_to BETA_EMAIL, t("#{scope}.#{kind}.link"), subject:, body:, class: "fr-notice__link"
    end
  end
end
