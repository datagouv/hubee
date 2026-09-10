# frozen_string_literal: true

module Portail
  module Attachments
    class Show
      class FetchContent
        include Interactor

        def call
          # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut « aucun
          # filtre », donc toute l'organisation. Même garde que la liste.
          out_of_perimeter if Access::ProcessPerimeter.none?(context.membership)
          # Ce que la gem refuserait sans pouvoir nous dire que la faute est ici : elle rend le
          # même type d'erreur pour un identifiant d'URL malformé — qui vaut « introuvable » — et
          # pour une entrée que NOUS avons mal calculée. Gardé avant l'appel, un défaut du portail
          # reste un incident visible au lieu de se déguiser en dossier inexistant.
          return malformed_request if author.blank? || perimeter_codes.any?(&:blank?)

          context.content = fetch
        end

        private

        # Un seul geste : la gem rapatrie l'octet ET inscrit le téléchargement à l'historique. La
        # trace n'est donc pas un second appel qu'un appelant pourrait oublier — c'est un effet de
        # l'action, et l'un ne peut pas avoir lieu sans l'autre.
        #
        # Les habilitations partent AVEC la demande : c'est la gem qui tranche le flux, avant de
        # rapatrier l'octet. Un oubli de ce mot-clé ouvrirait la lecture à toute l'organisation
        # sans que rien ne le signale — d'où la spec qui vérifie qu'il voyage.
        def fetch
          link = context.membership.organization_link
          HubAPI::Attachments.download(
            delivery_id: context.delivery_id,
            id: context.id,
            author: author,
            siret: link.siret,
            insee_code: link.insee_code,
            data_stream_codes: perimeter_codes
          )
        rescue HubAPI::NotFound
          out_of_perimeter
        rescue HubAPI::AttachmentNotFound
          not_found(:unknown)
        rescue HubAPI::AttachmentUnavailable
          content_unavailable
        rescue HubAPI::HistoryFull
          history_full
        rescue HubAPI::InvalidRequest
          # Vaut introuvable, comme sur le détail : les deux identifiants viennent de l'URL, et un
          # robot qui balaie des adresses malformées ne doit rien déclencher de plus.
          not_found(:invalid_id)
        rescue HubAPI::Error => e
          unavailable(e)
        end

        def perimeter_codes = Access::ProcessPerimeter.filter(context.membership)

        # Un défaut du portail, pas une donnée manquante : l'adresse d'un agent est obligatoire en
        # base et validée au modèle, un code d'habilitation ne peut pas être blanc. Y arriver quand
        # même veut dire qu'un invariant a cédé — signalé au rapporteur, pas avalé.
        def malformed_request
          Rails.error.report(ArgumentError.new("Requête de téléchargement malformée"),
            handled: true, context: {agent_id: context.agent.id, membership_id: context.membership.id})
          context.fail!(error: :unavailable)
        end

        # Ce que l'historique affichera. Le nom d'usage d'abord, comme les routes durcies de la V1 ;
        # l'adresse en repli, parce qu'une trace anonyme ne trace rien et que le nom est facultatif
        # côté fournisseur d'identité. Calculé ici et non sur le modèle : l'identité écrite en amont
        # est une affaire du portail, elle n'a rien à faire dans un modèle partagé.
        def author
          agent = context.agent

          [agent.first_name, agent.last_name].compact_blank.join(" ").presence || agent.email
        end

        # L'agent ne peut rien y faire et le service n'est pas en panne : le journaliser en
        # avertissement, avec la démarche, pour que la saturation se voie avant qu'un agent
        # n'appelle. La gem refuse AVANT de rapatrier l'octet : rien n'a été transféré pour rien.
        def history_full
          Rails.logger.warn("Historique de démarche saturé, téléchargement refusé",
            delivery_id: context.delivery_id, id: context.id)
          context.fail!(error: :history_full)
        end

        # Le bornage a refusé la lecture. Aucun motif n'est journalisé ici : la gem confond à
        # dessein ses quatre causes, et c'est le contrôleur qui porte le signalement au CSIRT.
        def out_of_perimeter = context.fail!(error: :out_of_perimeter)

        # En champs, pas dans le message : les identifiants se filtrent au journal, et `reason`
        # sépare la pièce que l'amont ne sert pas du bruit des identifiants malformés.
        def not_found(reason)
          Rails.logger.info("Pièce introuvable en amont",
            delivery_id: context.delivery_id, id: context.id, reason:)
          context.fail!(error: :not_found)
        end

        # La même page que la panne : l'agent voit la pièce à l'inventaire, lui répondre
        # « introuvable » contredirait l'écran qu'il a sous les yeux. En avertissement et non en
        # erreur : une pièce purgée est un cas courant et non un incident, mais une rafale de ces
        # refus en est un — c'est le volume qui doit se voir, pas chaque occurrence.
        def content_unavailable
          Rails.logger.warn("Contenu de pièce indisponible en amont",
            delivery_id: context.delivery_id, id: context.id)
          context.fail!(error: :content_unavailable)
        end

        # L'incident est déjà signalé par Portail::HubAPI, qui a traduit la panne : il ne reste
        # qu'à la journaliser et à échouer.
        def unavailable(error)
          Rails.logger.error("Pièce indisponible — #{error.class} : #{error.message}")
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
