# frozen_string_literal: true

module DataPackages
  class Transmit
    class TransitionToTransmitted
      include Interactor

      def call
        data_package.update!(
          state: :transmitted,
          sent_at: Time.current
        )
      end

      private

      def data_package
        context.data_package
      end
    end
  end
end
