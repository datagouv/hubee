# frozen_string_literal: true

module Portail
  # Le niveau de sensibilité d'une action, déclaré par le contrôleur qui la porte :
  #
  #   requires_reauthentication :very_sensitive, only: :create,
  #     purpose: -> { Access::Reauthentication.purpose(:credentials, params[:abonnement_id]) },
  #     with: :render_reauthentication_required
  #
  # Une action sans déclaration est standard : la session ouverte suffit. Ce que vaut une preuve, et
  # pendant combien de temps, est décrit par Portail::Access::Reauthentication.
  module Reauthentication
    extend ActiveSupport::Concern

    class_methods do
      # `purpose` est évalué dans le contrôleur : l'objet de la preuve dépend de la requête. `with`
      # nomme la réponse d'un refus, propre à chaque page ; sans elle, un 403 nu.
      def requires_reauthentication(level, purpose:, with: nil, **)
        Access::Reauthentication::WINDOWS.fetch(level) do
          raise ArgumentError, "niveau de sensibilité inconnu : #{level.inspect}"
        end

        before_action(**) do
          next if reauthenticated?(level, instance_exec(&purpose))

          with ? send(with) : head(:forbidden)
        end
      end
    end

    private

    # Très sensible : la preuve est consommée ici, avant l'action. Si l'action échoue ensuite,
    # l'agent se réauthentifie de nouveau — la sécurité prime sur le confort.
    def reauthenticated?(level, purpose)
      if level == :very_sensitive
        Access::Reauthentication.consume!(Current.provider_session, purpose:)
      else
        Access::Reauthentication.satisfied?(Current.provider_session, level:, purpose:)
      end
    end
  end
end
