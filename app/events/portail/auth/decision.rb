# frozen_string_literal: true

module Portail
  module Auth
    # Ce que le portail a décidé, et sur quelles bases. Un objet et non un Hash : les charges
    # utiles en Hash sont filtrées par filter_parameters, qui masquerait l'adresse et le
    # `sub` — précisément ce dont le support a besoin.
    #
    # Un Data et non une classe ordinaire : l'instance passe d'un abonné à l'autre, et aucun
    # ne doit pouvoir la modifier avant que le suivant ne la voie. Le jeu de clés est fermé
    # par le langage, pas par une convention — rien ne peut s'y glisser, un jeton compris.
    Decision = Data.define(:outcome, :reason, :email, :provider_sub, :siret,
      :organization_label, :idp_id, :acr, :amr, :agent_id, :membership_id,
      :provider_sub_changed) do
      def initialize(outcome:, reason: nil, email: nil, provider_sub: nil, siret: nil,
        organization_label: nil, idp_id: nil, acr: nil, amr: [], agent_id: nil,
        membership_id: nil, provider_sub_changed: false)
        super
      end
    end
  end
end
