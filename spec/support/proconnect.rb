# frozen_string_literal: true

# Simule un retour ProConnect via le mode test d'OmniAuth. La vérification
# cryptographique (TokenVerifier) est stubbée ici — elle est testée en propre
# dans spec/lib/portail/pro_connect/token_verifier_spec.rb (frontière : les request
# specs valident l'orchestration/UX, pas la crypto).
module ProConnectTestHelper
  def mock_proconnect(sub:, email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin", amr: ["mfa"])
    OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
      provider: "proconnect",
      uid: sub,
      info: {email:, first_name:, last_name:},
      credentials: {id_token: "test-id-token"},
      extra: {nonce: "test-nonce"}
    )
    # TokenVerifier renvoie l'identité vérifiée à partir de l'id_token.
    # expect (pas allow) : le callback DÉCLENCHE réellement cet appel une fois — la règle
    # « expect jamais allow » (rspec-conventions) s'applique, l'appel a bien lieu.
    expect(Portail::ProConnect::TokenVerifier).to receive(:call).and_return(sub:, amr:)
  end

  def sign_in_via_proconnect(agent:, amr: ["mfa"])
    mock_proconnect(sub: agent.provider_sub, email: agent.email, amr:)
    get "/auth/proconnect/callback"
  end
end

RSpec.configure do |config|
  config.include ProConnectTestHelper, type: :request
  config.before(:each, type: :request) { OmniAuth.config.test_mode = true }
  config.after(:each, type: :request) { OmniAuth.config.mock_auth[:proconnect] = nil }
end
