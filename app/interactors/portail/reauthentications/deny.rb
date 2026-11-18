# frozen_string_literal: true

module Portail
  module Reauthentications
    # Consigner un refus ne peut pas être une étape de Reauthentications::Complete : la chaîne a échoué,
    # et rien ne s'exécute après un fail!. D'où cet organizer distinct, comme pour la connexion.
    class Deny
      include Interactor::Organizer

      organize Deny::ClassifyRefusal, Deny::RecordRefusal
    end
  end
end
