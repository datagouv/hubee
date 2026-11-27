# frozen_string_literal: true

module Portail
  module Access
    # La preuve qu'un agent déjà connecté s'est réauthentifié récemment, et ce qu'elle autorise.
    # ProConnect n'atteste pas l'heure de la dernière saisie (`auth_time` vaut la fin de son parcours) :
    # la fraîcheur est celle d'une déconnexion puis d'une connexion déclenchées par le portail,
    # jamais celle de la session déjà ouverte. La règle ne peut pas vivre sur ProviderSession : un
    # modèle AR de `::` ne porte pas de logique d'un seul module.
    module Reauthentication
      # Très sensible : faite juste avant, pour cette action sur cet objet, et une seule fois.
      WINDOWS = {sensitive: 30.minutes, very_sensitive: 5.minutes}.freeze

      # Les actions sensibles du portail, chacune classée une seule fois : le garde qui la protège et
      # la page qui la propose en tirent son niveau, sans le réécrire.
      ACTIONS = {credentials: :very_sensitive}.freeze

      # Ce qu'une page peut dire d'une action sensible sur un objet : débloquée ou non, et jusqu'à
      # quand. Un état nommé, pour que la vue n'ait pas à lire un nil comme un signal.
      Status = Data.define(:unlocked_until) do
        def unlocked? = !unlocked_until.nil?
      end

      class << self
        def level(action) = ACTIONS.fetch(action) { raise ArgumentError, "action sensible inconnue : #{action.inspect}" }

        def purpose(action, subject_id) = "#{action}:#{subject_id}"

        # Pour l'affichage seulement : il n'ouvre rien, le garde reste seul à décider et à consommer.
        def status(provider_session, action:, subject_id:)
          level = level(action)
          unlocked = satisfied?(provider_session, level:, purpose: purpose(action, subject_id))
          Status.new(unlocked_until: (provider_session.reauthenticated_at + WINDOWS.fetch(level) if unlocked))
        end

        # Le nouvel id_token remplace l'ancien : celui-ci correspond à une session ProConnect fermée
        # par la réauthentification, « Se déconnecter » ne doit plus le présenter.
        def record!(provider_session, purpose:, id_token:, acr:, amr:)
          provider_session.update!(reauthenticated_at: Time.current, reauthenticated_for: purpose,
            reauthentication_consumed_at: nil, provider_id_token: id_token, acr:, amr:)
        end

        # Sans effet de bord : le garde d'une action sensible, et l'affichage. Le garde d'une action très
        # sensible passe par `consume!`.
        def satisfied?(provider_session, level:, purpose:)
          reauthenticated_at = provider_session&.reauthenticated_at
          return false if reauthenticated_at.nil? || reauthenticated_at <= WINDOWS.fetch(level).ago
          return true if level == :sensitive

          provider_session.reauthenticated_for == purpose && provider_session.reauthentication_consumed_at.nil?
        end

        # Une seule requête conditionnelle : de deux consultations simultanées, une seule passe. La
        # session est rechargée ensuite : restée périmée, un `record!` suivant ne verrait pas la
        # consommation à effacer et ne l'écrirait pas.
        def consume!(provider_session, purpose:)
          consumed = ProviderSession
            .where(id: provider_session.id, reauthenticated_for: purpose, reauthentication_consumed_at: nil)
            .where(reauthenticated_at: WINDOWS.fetch(:very_sensitive).ago..)
            .update_all(reauthentication_consumed_at: Time.current) == 1
          provider_session.reload if consumed
          consumed
        end
      end
    end
  end
end
