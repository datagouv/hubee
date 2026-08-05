# frozen_string_literal: true

module Portail
  module Sessions
    # Consigner un refus ne peut pas être une étape de Sessions::Create : la chaîne a
    # échoué, et rien ne s'exécute après un fail!. D'où cet organizer distinct.
    class Deny
      include Interactor::Organizer

      organize Deny::RecordRefusal
    end
  end
end
