# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      class VerifyIdToken
        include Interactor

        def call
          context.claims = Portail::ProConnect::TokenVerifier.call(
            id_token: context.id_token,
            nonce: context.nonce,
            audience: ENV.fetch("PROCONNECT_CLIENT_ID")
          )
        rescue Portail::ProConnect::TokenVerifier::InvalidToken => e
          Rails.logger.warn("[ProConnect] id_token rejected: #{e.message}")
          context.fail!(error: :invalid_token)
        end
      end
    end
  end
end
