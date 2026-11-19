# frozen_string_literal: true

# L'en-tête d'un appel authentifié à l'API : un jeton neuf, délivré au client donné, dont les droits
# décident seuls de la réponse.
module APIAccessTokenHelper
  def bearer(application)
    {"Authorization" => "Bearer #{create(:oauth_access_token, application:).plaintext_token}"}
  end
end

RSpec.configure do |config|
  config.include APIAccessTokenHelper, type: :request
end
