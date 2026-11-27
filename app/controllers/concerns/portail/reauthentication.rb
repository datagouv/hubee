# frozen_string_literal: true

module Portail
  # Le garde d'une action sensible, déclaré par le contrôleur qui la porte. Son niveau vient du
  # classement des actions (Portail::Access::Reauthentication::ACTIONS) :
  #
  #   requires_reauthentication :credentials, only: :create,
  #     subject: -> { params[:abonnement_id] }, return_to: -> { abonnement_path(params[:abonnement_id]) }
  #
  # Une action sans déclaration est standard : la session ouverte suffit. Sans preuve valable, l'agent
  # part se réauthentifier, puis revient sur `return_to` et refait son geste : rien ne se rejoue seul,
  # et un formulaire se retrouve tel que l'agent l'a laissé. Le contrôleur d'une page qui propose
  # l'action peut, s'il le veut, dire si elle est débloquée (`reauthentication_status`), sans
  # rien ouvrir : seul le garde décide. Ce que vaut une preuve, et pendant combien de temps, est décrit
  # par Portail::Access::Reauthentication.
  module Reauthentication
    extend ActiveSupport::Concern

    # Le temps d'un aller-retour chez ProConnect. Au-delà, le parcours est abandonné : un retour
    # tardif ne réveille pas une réauthentification oubliée.
    PENDING_TTL = 10.minutes

    class_methods do
      # `subject` et `return_to` sont évalués dans le contrôleur : ils dépendent de la requête. Le
      # niveau est lu à chaque requête : une action non classée échoue à son premier appel.
      def requires_reauthentication(action, subject:, return_to:, **)
        before_action(**) do
          level = Access::Reauthentication.level(action)
          purpose = Access::Reauthentication.purpose(action, instance_exec(&subject))
          next if reauthenticated?(level, purpose)

          start_reauthentication(action:, purpose:, return_to: instance_exec(&return_to))
        end
      end
    end

    private

    # Pour le contrôleur d'une page qui propose une action sensible, à passer à sa vue : si l'action est
    # débloquée sur cet objet, et jusqu'à quand (Access::Reauthentication::Status). N'ouvre rien et ne
    # consomme rien.
    def reauthentication_status(action, subject_id)
      Access::Reauthentication.status(Current.provider_session, action:, subject_id:)
    end

    # Le parcours en cours dans ce navigateur, s'il est récent et appartient à la session ouverte.
    # Sinon il est oublié : sans agent connecté, ou sur une autre session, il ne vaut plus rien.
    def pending_reauthentication
      pending = session[:reauthentication]
      return if pending.nil?

      return pending if Current.provider_session.present? &&
        pending["provider_session_id"] == Current.provider_session.id &&
        pending["started_at"] > PENDING_TTL.ago.to_i

      session.delete(:reauthentication)
      nil
    end

    # Très sensible : la preuve est consommée ici, avant l'action. Si l'action échoue ensuite,
    # l'agent se réauthentifie de nouveau — la sécurité prime sur le confort.
    def reauthenticated?(level, purpose)
      if level == :very_sensitive
        Access::Reauthentication.consume!(Current.provider_session, purpose:)
      else
        Access::Reauthentication.satisfied?(Current.provider_session, level:, purpose:)
      end
    end

    # Déconnecte l'agent de ProConnect, y compris de ses autres services : sa session ProConnect, ou
    # celle de son fournisseur d'identité, ne doit pas suffire à la reconnexion qui suit. Ce que la
    # suite relit vient de la requête interceptée, jamais d'un paramètre du navigateur. Une seule
    # demande à la fois : une autre action interceptée entre-temps la remplace.
    def start_reauthentication(action:, purpose:, return_to:)
      logout_url = reauthentication_logout_url
      # ProConnect injoignable : rien n'a été fermé, l'agent retrouve sa page.
      return redirect_to(return_to, alert: t("portail.reauthentications.failed")) if logout_url.nil?

      session[:reauthentication] = {
        "action" => action.to_s, "purpose" => purpose, "return_to" => return_to,
        "provider_session_id" => Current.provider_session.id, "started_at" => Time.current.to_i
      }
      redirect_to logout_url, allow_other_host: true, status: :see_other
    end

    # Le seul appel qui peut échouer, isolé : nil quand ProConnect ne répond pas.
    def reauthentication_logout_url
      Portail::ProConnect::Client.reauthentication_logout_url(id_token: Current.provider_session.provider_id_token)
    rescue Portail::ProConnect::Client::Unavailable => e
      Rails.logger.error("ProConnect indisponible", e)
      nil
    end
  end
end
