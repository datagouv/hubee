# frozen_string_literal: true

# Aucun abonné n'est branché par défaut : sans cet initializer, `Rails.event.notify` est un
# no-op silencieux.
#
# L'adaptateur résout la classe à l'émission. Un initializer ne peut pas référencer une
# constante autochargée, et une instance retenue au démarrage deviendrait périmée au premier
# rechargement — Rails.event garde ses abonnés pour la vie du processus.
lazy = Struct.new(:class_name) do
  def emit(event) = class_name.constantize.new.emit(event)
end

# Le filtre porte sur le type : avec un objet, notify nomme l'événement d'après sa classe,
# il n'y a pas de chaîne pointée à préfixer.
decision = ->(event) { event[:payload].is_a?(Portail::Auth::Decision) }

Rails.event.subscribe(lazy.new("Portail::Auth::DecisionLogger"), &decision)
Rails.event.subscribe(lazy.new("Portail::Auth::Recorder"), &decision)
