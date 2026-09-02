# frozen_string_literal: true

module Portail
  class DeliveriesController < Portail::BaseController
    # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
    # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
    DEFAULT_STATE = "transmitted"

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
      report_upstream_mismatch(@list.deliveries - @deliveries)
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

    # L'amont n'a pas tenu son contrat : signalé, Sentry et canal CSIRT, mais pas refusé en
    # bloc. Un filtre non respecté est une anomalie amont, pas une raison de priver l'agent de
    # sa page.
    def report_upstream_mismatch(dropped)
      return if dropped.empty?

      Rails.event.notify("portail.access.upstream_mismatch",
        membership_id: current_membership.id, delivery_ids: dropped.map(&:id))
      Sentry.capture_message("L'amont a servi des démarches hors du périmètre demandé", level: :warning)
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
