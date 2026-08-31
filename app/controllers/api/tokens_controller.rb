# frozen_string_literal: true

module API
  # Seule surface non authentifiée de l'API : sans frein, un inconnu essaie des couples
  # client/secret en boucle. Un client légitime demande un jeton toutes les deux heures.
  class TokensController < Doorkeeper::TokensController
    RATE_LIMIT_PER_MINUTE = 10

    # `by:` explicite bien que ce soit le défaut de Rails : la clé est la partie sécuritaire
    # de la déclaration, elle ne se devine pas.
    rate_limit to: RATE_LIMIT_PER_MINUTE, within: 1.minute,
      by: -> { request.remote_ip },
      with: -> { render json: {error: "rate_limited"}, status: :too_many_requests }
  end
end
