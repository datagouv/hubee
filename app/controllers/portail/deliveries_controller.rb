# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
    # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
    DEFAULT_STATE = "transmitted"

    def index
      # L'état affiché, relu par la vue. `.to_s` : `?statut[]=…` fait de la valeur un tableau.
      # Aucune validation : l'amont tranche, et son refus est affiché plutôt que corrigé en douce.
      @current_state = params[:statut].to_s.presence || DEFAULT_STATE

      result = Deliveries::Index.call(
        membership: current_membership, state: @current_state, page: requested_page
      )

      unless result.success?
        # Rien à borner : aucune page n'a été lue.
        skip_policy_scope
        return explain_failure(result.error)
      end

      # La requête était déjà bornée par le rattachement ; le scope borne ce que l'amont a
      # réellement servi, sans lui faire confiance. La policy est nommée : Pundit ne la
      # déduirait pas d'un tableau. La liste brute reste ici : la vue ne voit que le borné.
      @page = result.list.page
      @deliveries = policy_scope(result.list.deliveries, policy_scope_class: DeliveryPolicy::Scope)

      # L'amont n'a pas tenu son contrat : signalé, pas refusé en bloc. Un filtre non respecté
      # est une anomalie amont, pas une raison de priver l'agent de sa page.
      report_upstream_mismatch(result.list.deliveries)
    end

    def show
      result = Deliveries::Show.call(membership: current_membership, id: params[:id])

      unless result.success?
        # Rien à autoriser : aucune démarche n'a été trouvée.
        skip_authorization
        return (result.error == :not_found) ? not_found : unavailable
      end

      # Sans cette ligne, un identifiant connu ouvrirait une démarche hors habilitation. La
      # policy vérifie aussi l'organisation servie : l'amont n'est pas cru sur parole.
      @delivery = authorize(result.delivery)
    end

    private

    def report_upstream_mismatch(served)
      dropped = served - @deliveries
      return if dropped.empty?

      Rails.event.notify(Access::Refusal.new(reason: :upstream_mismatch, path: request.path,
        membership_id: current_membership.id, dropped_ids: dropped.map(&:id)))
    end

    # Toujours 200, sur la page de la liste. Deux familles : le portail refuse de lui-même, ou
    # l'amont a échoué, et la vue ne dit alors que la conséquence, le flash portant le motif.
    def explain_failure(error)
      if error == :no_habilitation
        @failure = :no_habilitation
      else
        @failure = :upstream
        flash.now[:alert] = t("portail.deliveries.errors.#{error}")
      end
    end

    # `.presence` : `?page=` vide retombe sur la première page. Une valeur trafiquée donne 0,
    # donc un décalage négatif que l'amont refuse.
    def requested_page = params[:page].to_s.presence&.to_i || 1
  end
end
