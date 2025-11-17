# frozen_string_literal: true

module DataPackages
  class Transmit
    class CreateNotifications
      include Interactor

      def call
        return if context.target_subscriptions.empty?

        data_package.update!(notifications_attributes: notifications_attributes)
      end

      def rollback
        data_package.notifications.destroy_all
      end

      private

      def data_package
        context.data_package
      end

      def notifications_attributes
        context.target_subscriptions.pluck(:id).map do |subscription_id|
          {subscription_id: subscription_id}
        end
      end
    end
  end
end
