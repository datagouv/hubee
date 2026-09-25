# frozen_string_literal: true

module Portail
  module Deliveries
    # L'état d'un télédossier. Une seule action, et rien à rendre : la réponse est le détail relu.
    class StatesController < Portail::BaseController
      include NestedInDelivery

      # Ce qui ne se lit pas ne s'écrit pas.
      before_action :set_delivery, only: :update

      def update
        authorize(@delivery)

        result = States::Update.call(
          membership: current_membership, delivery: @delivery,
          state: params[:etat].to_s, author: EventAuthor.for(current_agent)
        )

        # 303 et non 302 : la convention Rails après écriture, qui lève toute ambiguïté sur la
        # méthode rejouée.
        redirect_to teledossier_path(@delivery.id), status: :see_other, **outcome(result)
      end

      private

      # Succès comme refus renvoient au détail, qui relit l'amont : le portail n'affiche jamais
      # un état qu'il aurait déduit. `raise: true` : un refus sans libellé doit exploser ici, pas
      # s'afficher en clé brute.
      def outcome(organizer_result)
        return {notice: t("portail.deliveries.change_state.saved")} if organizer_result.success?

        {alert: t("portail.deliveries.change_state.errors.#{organizer_result.error}", raise: true)}
      end
    end
  end
end
