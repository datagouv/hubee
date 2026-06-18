# frozen_string_literal: true

module API
  module DataPackages
    class Transmit
      include Interactor::Organizer

      organize Transmit::ValidateTransmission,
        Transmit::ResolveRecipients,
        Transmit::CreateNotifications,
        Transmit::TransitionToTransmitted
    end
  end
end
