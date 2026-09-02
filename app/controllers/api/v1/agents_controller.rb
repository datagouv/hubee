# frozen_string_literal: true

module API
  module V1
    class AgentsController < BaseController
      # ActionController::API ne fournit pas `t`.
      include AbstractController::Translation

      STATUSES = {
        invalid_payload: :unprocessable_entity,
        organization_unknown: :unprocessable_entity,
        email_taken: :conflict,
        referential_unavailable: :service_unavailable
      }.freeze

      def create
        result = Agents::Create.call(
          payload: AgentPayload.new(agent_params),
          api_client: current_api_client.name,
          request_id: request.request_id
        )

        if result.success?
          @agent = result.agent
          @memberships = result.memberships
          render :show, status: :created
        else
          render json: result.fields || error_fields(result),
            status: STATUSES.fetch(result.error)
        end
      end

      private

      def agent_params
        params.expect(agent: [:email, :first_name, :last_name, :civility,
          {memberships: [[:siret, :insee_code, :role, :job_title, :phone_number]]}])
      end

      # Même rôle qu'error_response chez les transmissions : traduire un symbole sec en hash
      # plat, le format d'erreur de toute l'API. Les échecs de validation portent déjà le leur.
      def error_fields(result)
        case result.error
        when :email_taken
          {email: [t("api.agents.errors.email_taken")]}
        when :organization_unknown
          {"memberships[#{result.membership_index}].insee_code": [t("api.agents.errors.organization_unknown")]}
        when :referential_unavailable
          {base: [t("api.agents.errors.referential_unavailable")]}
        end
      end
    end
  end
end
