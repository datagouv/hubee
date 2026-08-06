# frozen_string_literal: true

module Portail
  module Auth
    # Ce que le portail a décidé, et sur quelles bases. Un objet et non un Hash :
    # filter_parameters masquerait l'adresse et le `sub`, dont le support a besoin.
    # Un Data : immuable d'un abonné à l'autre, jeu de clés fermé par le langage.
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
