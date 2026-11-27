# frozen_string_literal: true

module Portail
  # Tant que les agents de la V1 ne sont pas importés, un agent inconnu est d'abord l'un d'eux :
  # la page de refus le renvoie vers le portail actuel plutôt que vers son administration.
  module V2OpeningHelper
    CURRENT_PORTAL_URL = "https://portail.hubee.numerique.gouv.fr/"

    # Coupure explicite, comme le bandeau de la bêta : l'ouverture n'attend pas une livraison de code.
    def before_v2_opening?(denial) =
      denial.denial_reason == "unknown_agent" && ENV["SESSION_DENIED_BEFORE_V2_OPENING"] == "true"
  end
end
