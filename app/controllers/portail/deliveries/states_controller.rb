# frozen_string_literal: true

module Portail
  module Deliveries
    # L'état d'un télédossier. Une seule action, et rien à rendre : la réponse est le détail relu.
    class StatesController < Portail::BaseController
      before_action :set_delivery, only: :update

      def update
        authorize(@delivery)

        result = States::Update.call(
          membership: current_membership, delivery: @delivery,
          state: params[:etat].to_s, seen_state: params[:etat_vu].to_s,
          author: EventAuthor.for(current_agent)
        )

        # 303 et non 302 : la convention Rails après écriture, qui lève toute ambiguïté sur la
        # méthode rejouée.
        redirect_to teledossier_path(@delivery.id), status: :see_other, **outcome(result)
      end

      private

      # Mêmes refus que le détail : ce qui ne se lit pas ne s'écrit pas. Un rendu ici coupe la
      # chaîne, la vérification d'autorisation ne tourne pas : rien à lever.
      def set_delivery
        result = Deliveries::Show.call(membership: current_membership, id: params[:teledossier_id])

        if result.success?
          @delivery = result.delivery
        else
          (result.error == :not_found) ? not_found : unavailable
        end
      end

      # Succès comme refus renvoient au détail, qui relit l'amont : le portail n'affiche jamais
      # un état qu'il aurait déduit, et le rechargement qu'on demande est cette redirection.
      # `raise: true` : un refus sans libellé doit exploser ici, pas s'afficher en clé brute.
      def outcome(result)
        return {notice: t("portail.deliveries.change_state.saved")} if result.success?

        {alert: t("portail.deliveries.change_state.errors.#{result.error}", raise: true)}
      end
    end
  end
end
