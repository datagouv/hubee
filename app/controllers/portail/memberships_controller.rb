# frozen_string_literal: true

module Portail
  class MembershipsController < Portail::BaseController
    # Un membre n'a pas à faire lire la base ni appeler l'amont pour une 404.
    before_action :require_local_administrator

    def index
      # Le tableau `[:portail, …]` désigne Portail::MembershipPolicy : le modèle est ::Membership.
      authorize [:portail, Membership]

      # NULL en dernier, l'ordre par défaut de PostgreSQL : un agent sans nom ne passe pas devant.
      @memberships = policy_scope([:portail, Membership])
        .joins(:agent).includes(:agent, :data_stream_accesses)
        .order("agents.last_name", "agents.first_name", "agents.email")

      result = Memberships::Index.call(membership: current_membership)
      @data_stream_names = result.data_stream_names
      @subscribed_data_stream_codes = result.subscribed_data_stream_codes
    end
  end
end
