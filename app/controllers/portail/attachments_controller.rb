# frozen_string_literal: true

module Portail
  # Le contenu d'une pièce d'une démarche. Une seule action, et rien à rendre : la réponse est le
  # fichier lui-même.
  class AttachmentsController < Portail::BaseController
    # Le contrôleur de base accroche ses deux gardes à l'action `index`, que ce contrôleur n'a
    # pas — et Rails refuse depuis 7.1 un callback qui cible une action absente. On les repose
    # donc ici, sur la seule action servie : `show` doit autoriser, et il n'y a aucune liste à
    # borner. Reposer plutôt que retirer : la garde d'autorisation est ce qui ferme ce contrôleur.
    skip_after_action :verify_authorized, :verify_policy_scoped
    after_action :verify_authorized

    def show
      result = Attachments::Show.call(
        membership: current_membership, agent: current_agent,
        delivery_id: params[:demarche_id], id: params[:id]
      )

      return refuse(result.error) unless result.success?

      # La ceinture, pas la bretelle : la gem a borné la lecture sur l'organisation ET le flux, et
      # inscrit la trace dans le même geste. La policy vérifie ici qu'elle a tenu ce contrat, sur
      # la démarche réellement servie — même défiance que le `policy_scope` de la liste.
      #
      # Elle tombe APRÈS l'écriture de la trace, et ce n'est pas une perte : les octets ont bien
      # été retirés de l'amont avant qu'on refuse de les remettre. La trace dit donc vrai. Refuser
      # plus tôt ne les y remettrait pas — ça effacerait seulement la ligne qui l'atteste.
      authorize(result.content.delivery, :show?)

      deliver(result.content)
    end

    private

    # Sa propre page : la 503 promettrait « réessayez dans quelques instants », or rien ne se
    # libérera. 409 et non 503 — la demande est recevable, c'est l'état de la démarche qui s'y
    # oppose.
    def history_full
      render("portail/errors/history_full", status: :conflict)
    end

    # `attachment` toujours, jamais `inline` : le type de contenu vient de l'amont, il n'a pas à
    # décider qu'un fichier s'ouvre dans l'onglet de l'agent. Le contenu ne fait que traverser —
    # le `no-store` du contrôleur de base couvre déjà la réponse.
    def deliver(content)
      send_data(content.body,
        filename: content.attachment.filename,
        type: content.attachment.content_type,
        disposition: "attachment")
    end

    def refuse(error)
      # Rien à autoriser : aucune démarche n'a été servie.
      skip_authorization

      case error
      # Cette adresse ne s'atteint qu'après un détail légitimement consulté : un refus de bornage
      # y est anormal quelle qu'en soit la cause, et part au CSIRT par le canal des refus d'accès.
      # Sur le détail, ouvert au balayage, le même refus ne serait que du bruit.
      #
      # ⚠️ À lire en AGRÉGAT, pas à l'occurrence : le monde change entre le rendu de la page et le
      # clic. Une démarche archivée ou une habilitation révoquée entre les deux produisent le même
      # refus, sans que rien d'anormal ne se soit passé. C'est une rafale qui est un signal.
      when :out_of_perimeter then refuse_access
      when :not_found then not_found
      # L'amont n'a pas pu servir l'octet et ne dit pas pourquoi. Sa cause la plus courante est
      # une pièce dont le binaire a été purgé alors que son état annonce toujours « reçue » :
      # promettre « réessayez » serait faux, et parler de panne serait à côté.
      when :content_unavailable then content_unavailable
      # L'historique de la démarche n'accepte plus d'événement, donc le téléchargement ne peut pas
      # être tracé, donc il n'a pas lieu.
      when :history_full then history_full
      else unavailable
      end
    end

    def content_unavailable
      render("portail/errors/attachment_unavailable", status: :service_unavailable)
    end
  end
end
