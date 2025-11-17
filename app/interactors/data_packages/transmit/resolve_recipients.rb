# frozen_string_literal: true

module DataPackages
  class Transmit
    class ResolveRecipients
      include Interactor

      def call
        context.target_subscriptions = DeliveryCriteria::Resolver.resolve(
          data_package.delivery_criteria,
          data_package.data_stream
        )

        context.fail!(error: :no_recipients) unless context.target_subscriptions.exists?
      end

      private

      def data_package
        context.data_package
      end
    end
  end
end
