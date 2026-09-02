# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
    # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
    DEFAULT_STATE = "transmitted"

    # L'amont n'a pas tenu son contrat : signalé, pas refusé en bloc. Un filtre non respecté
    # est une anomalie amont, pas une raison de priver l'agent de sa page.
    after_action :report_upstream_mismatch, only: :index, if: -> { @deliveries }

    def index
      result = Deliveries::Index.call(
        membership: current_membership, state: current_state, page: requested_page
      )

      unless result.success?
        # Rien à borner : aucune page n'a été lue.
        skip_policy_scope
        return render_failure(result.error)
      end

      # La requête était déjà bornée par le rattachement ; le scope borne ce que l'amont a
      # réellement servi, sans lui faire confiance. La policy est nommée : Pundit ne la
      # déduirait pas d'un tableau.
      @list = result.list
      @deliveries = policy_scope(@list.deliveries, policy_scope_class: DeliveryPolicy::Scope)
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

    def report_upstream_mismatch
      dropped = @list.deliveries - @deliveries
      return if dropped.empty?

      Rails.event.notify(Access::Decision.new(outcome: :upstream_mismatch, path: request.path,
        membership_id: current_membership.id, dropped_ids: dropped.map(&:id)))
    end

    def render_failure(error)
      return render(:no_habilitation) if error == :no_habilitation

      # Toujours 200 : le portail a servi sa page, c'est un service tiers qui manque.
      flash.now[:alert] = t("portail.deliveries.errors.#{error}")
      render :degraded
    end

    # L'état affiché, relu par la vue. `.to_s` : `?statut[]=…` fait de la valeur un tableau.
    # Aucune validation : l'amont tranche, et son refus est affiché plutôt que corrigé en douce.
    def current_state = @current_state ||= params[:statut].to_s.presence || DEFAULT_STATE

    # `.presence` : `?page=` vide retombe sur la première page. Une valeur trafiquée donne 0,
    # donc un décalage négatif que l'amont refuse.
    def requested_page = params[:page].to_s.presence&.to_i || 1
  end
end
