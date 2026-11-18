# frozen_string_literal: true

module Portail
  module Reauthentications
    class Create
      # L'ancien id_token correspond à la session ProConnect fermée au départ de la réauthentification.
      class AdoptIdToken
        include Interactor

        def call
          context.provider_session.update!(provider_id_token: context.id_token,
            acr: context.claims[:acr], amr: context.claims[:amr])
        end
      end
    end
  end
end
