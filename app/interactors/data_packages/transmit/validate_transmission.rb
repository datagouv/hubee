# frozen_string_literal: true

module DataPackages
  class Transmit
    class ValidateTransmission
      include Interactor

      def call
        context.fail!(error: :not_draft) unless data_package.draft?
        context.fail!(error: :no_completed_attachments) unless data_package.has_completed_attachments?
      end

      private

      def data_package
        context.data_package
      end
    end
  end
end
