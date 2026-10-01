# frozen_string_literal: true

module Portail
  module Deliveries
    # L'état d'un télédossier. Une seule action, dont la réponse est le détail : redirigé sur un
    # succès, rendu sur un refus avec la saisie de l'agent.
    class StatesController < Portail::BaseController
      include NestedInDelivery

      # Ce qui ne se lit pas ne s'écrit pas.
      before_action :set_delivery, only: :update

      def update
        authorize(@delivery)

        reply = Portail::Delivery::Reply.of(params[:piece])
        result = organizer_for(reply).call(
          membership: current_membership, delivery: @delivery, state: params[:etat].to_s,
          author: EventAuthor.for(current_agent), reply: reply,
          message: Portail::Delivery::StateMessage.of(params[:message])
        )

        return render_refusal(result) unless result.success?

        # 303 : la convention Rails après écriture. Le détail relit l'amont, jamais un état déduit.
        redirect_to teledossier_path(@delivery.id), status: :see_other, notice: notice_for(result)
      end

      private

      # Avec une pièce, la réponse part avant l'état : un organizer par geste.
      def organizer_for(reply) = reply ? States::UpdateWithReply : States::Update

      # Le détail lu en tête de requête, saisie comprise : l'agent relance sans retaper. `raise: true` :
      # un refus sans libellé explose ici plutôt que de s'afficher en clé brute.
      def render_refusal(result)
        reason = t("portail.deliveries.change_state.errors.#{result.error}", raise: true,
          state: Portail::Delivery.state_label(result.state), max: Portail::Delivery::StateMessage::MAX_LENGTH)
        flash.now[:alert] = result.reply_event ?
          t("portail.deliveries.change_state.attachment_sent_state_unchanged", reason: reason) : reason
        @data_stream = HubAPI::DataStreams.fetch(@delivery.data_stream_code)
        @state_message = result.message
        render "portail/deliveries/show", status: :unprocessable_content
      end

      def notice_for(result)
        t("portail.deliveries.change_state.#{result.reply_event ? "saved_with_attachment" : "saved"}")
      end
    end
  end
end
