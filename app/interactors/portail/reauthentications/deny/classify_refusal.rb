# frozen_string_literal: true

module Portail
  module Reauthentications
    class Deny
      # Ce que vaut un refus : son motif, et s'il ferme la session. Un autre rattachement ou une
      # déconnexion évitée la ferment, comme une session trop ancienne pour prouver la déconnexion, que
      # l'agent doit rouvrir. Un abandon, un refus de ProConnect ou une panne ne disent rien de qui est
      # au poste.
      class ClassifyRefusal
        include Interactor

        # Quelqu'un d'autre que le rattachement de la session est revenu : le collègue au poste, qui n'a
        # pu entrer qu'avec son propre compte.
        MISMATCHES = %i[reauthentication_mismatch unknown_agent email_mismatch organization_mismatch].freeze

        # Un jeton invalide est déjà tracé par sa vérification ; une panne n'est imputable à personne.
        UNTRACED = %i[invalid_token provider_unavailable].freeze

        CLOSING = %i[reauthentication_mismatch reauthentication_without_logout reauthentication_unprovable].freeze

        def call
          context.reason = MISMATCHES.include?(context.error) ? :reauthentication_mismatch : context.error
          context.close_session = CLOSING.include?(context.reason)
          context.traced = !UNTRACED.include?(context.error)
        end
      end
    end
  end
end
