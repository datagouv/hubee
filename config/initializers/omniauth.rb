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
    scope: "openid given_name usual_name email siret organization_label"
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
