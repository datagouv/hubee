# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # Le niveau est lu dans le jeton vérifié, jamais ailleurs : ce qui a été demandé au
      # départ ne prouve rien de ce qui a été atteint.
      class CheckSecondFactor
        include Interactor

        def call
          return if Access::SecondFactor.satisfied?(context.membership,
            acr: context.claims[:acr], amr: context.claims[:amr])

          # Une seule élévation : redemander enverrait l'agent en boucle entre les deux
          # services.
          context.fail!(error: context.step_up_attempted ? :second_factor_required : :step_up_required)
        end
      end
    end
  end
end
