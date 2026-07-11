# Be sure to restart your server when you modify this file.

# Politique CSP minimale (defense-in-depth, ticket #509).
# Dérivée du stack V2 (importmap + DSFR), pas recopiée du code V1 :
# - script-src : 'self' + nonce → importmap-rails pose le nonce automatiquement
#   sur ses balises ; pas de 'unsafe-inline' JS.
# - style-src : 'unsafe-inline' SANS nonce → requis par les styles inline posés
#   au runtime par DSFR (attributs style="" via JS). En CSP3, un nonce sur
#   style-src désactiverait 'unsafe-inline' et casserait le rendu DSFR.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.object_src :none
    policy.img_src :self, :data
    policy.font_src :self, :data
    policy.connect_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline
  end

  # Nonce aléatoire par requête (et non request.session.id) : V2 n'utilise pas
  # de session, donc session.id serait nil → nonce vide → CSP inopérante.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
