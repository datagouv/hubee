# frozen_string_literal: true

require Rails.root.join("lib/omni_auth/strategies/proconnect_hardened").to_s

Rails.application.config.middleware.use OmniAuth::Builder do
  provider OmniAuth::Strategies::ProconnectHardened,
    client_id: ENV["PROCONNECT_CLIENT_ID"],
    client_secret: ENV["PROCONNECT_CLIENT_SECRET"],
    proconnect_domain: ENV["PROCONNECT_DOMAIN"],
    redirect_uri: ENV["PROCONNECT_REDIRECT_URI"],
    post_logout_redirect_uri: ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"],
    scope: "openid given_name usual_name email siret organization_label"
end

OmniAuth.config.logger = Rails.logger
