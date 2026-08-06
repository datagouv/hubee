# frozen_string_literal: true

require Rails.root.join("lib/omni_auth/strategies/proconnect_hardened").to_s

Rails.application.config.middleware.use OmniAuth::Builder do
  provider OmniAuth::Strategies::ProconnectHardened,
    client_id: ENV["PROCONNECT_CLIENT_ID"],
    client_secret: ENV["PROCONNECT_CLIENT_SECRET"],
    proconnect_domain: ENV["PROCONNECT_DOMAIN"],
    redirect_uri: ENV["PROCONNECT_REDIRECT_URI"],
    post_logout_redirect_uri: ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"],
    # organization_label : sans lui, un refus de rattachement ne peut pas nommer
    # l'organisation présentée, et l'agent n'a aucun moyen de comprendre son refus.
    #
    # idp_id : quel fournisseur d'identité a authentifié l'agent, consigné dans les traces
    # de décision. Le scope demande une habilitation du support ProConnect — sans elle, la
    # demande d'autorisation échoue ENTIÈREMENT et plus personne ne se connecte. Retirer ce
    # mot suffit à revenir en arrière.
    scope: "openid given_name usual_name email siret organization_label idp_id"
end

OmniAuth.config.logger = Rails.logger

# OmniAuth lève par défaut en développement, ce qui traite de la même façon deux choses
# opposées : une panne de ProConnect, qui est un événement d'exploitation et mérite notre
# page d'échec, et une exception de notre côté, qui est un bug et mérite sa trace.
#
# La distinction est dans l'enveloppe : `fail!` porte un objet exception dans le second
# cas seulement.
OmniAuth.config.failure_raise_out_environments = []
OmniAuth.config.on_failure = proc do |env|
  raise env["omniauth.error"] if env["omniauth.error"] && Rails.env.local?

  OmniAuth::FailureEndpoint.call(env)
end
