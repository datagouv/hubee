# frozen_string_literal: true

module API
  module Internal
    class AgentsController < API::Internal::BaseController
      REFUSALS = {
        already_attached: {attribute: :email, status: :conflict},
        siret_already_attached: {attribute: :insee_code, status: :conflict},
        unknown_organization: {attribute: :siret, status: :unprocessable_content},
        unknown_data_stream: {attribute: :data_stream_codes, status: :unprocessable_content}
      }.freeze

      # Sans quoi Rails envelopperait lui-même un payload qui a oublié la clé `agent`.
      wrap_parameters false

      before_action :require_registration_right
      rescue_from ActionController::ParameterMissing, with: :missing_envelope

      def create
        form = AgentForm.new(**agent_params)
        result = Agents::Create.call(form:, api_client: current_api_client, request_id: request.request_id)

        if result.success?
          @membership = result.membership
          render :create, status: :created
        else
          render_refusal(form, Array(result.refusals))
        end
      end

      private

      # Lu à chaque appel : un droit retiré vaut aussitôt, même pour un jeton déjà délivré.
      def require_registration_right
        return if OauthApplicationRight.exists?(
          oauth_application: current_api_client, right: "internal:agents:create"
        )

        render json: {error: I18n.t("api.internal.agents.forbidden")}, status: :forbidden
      end

      def agent_params
        params.expect(agent: [
          :email, :first_name, :last_name, :civility,
          membership: [:siret, :insee_code, :role, :job_title, :phone_number, :mobile_phone_number]
        ]).to_h.deep_symbolize_keys.deep_merge(membership: data_stream_codes_param)
      end

      # Lus dans le JSON brut : les paramètres de Rails font de [null] une liste vide, et leur filtrage
      # écarte une liste mal formée. L'une ou l'autre donnerait tous les flux à un administrateur
      # local ; le form refuse ce qui n'est pas une liste de chaînes, et une liste absente. Hors d'un
      # corps JSON objet (l'agent peut venir de l'URL), la liste est absente.
      def data_stream_codes_param
        body = JSON.parse(request.raw_post) if request.media_type == Mime[:json]
        agent = body["agent"] if body.is_a?(Hash)
        membership = agent["membership"] if agent.is_a?(Hash)
        return {} unless membership.is_a?(Hash) && membership.key?("data_stream_codes")

        {data_stream_codes: membership["data_stream_codes"]}
      rescue JSON::ParserError
        {}
      end

      # Un refus est un motif, ou un motif et les paramètres de son message. Un conflit
      # l'emporte ; l'indisponibilité seule n'est rendue que sans aucun motif.
      def render_refusal(form, refusals)
        refusals.each { |reason, options = {}| form.errors.add(REFUSALS.fetch(reason)[:attribute], reason, **options) }

        if form.errors.empty?
          render json: {error: I18n.t("api.internal.agents.unavailable")}, status: :service_unavailable
        elsif refusals.any? { |reason, _| REFUSALS.fetch(reason)[:status] == :conflict }
          render json: form.error_details, status: :conflict
        else
          render json: form.error_details, status: :unprocessable_content
        end
      end

      def missing_envelope
        render json: {error: I18n.t("api.internal.agents.missing_envelope")}, status: :bad_request
      end
    end
  end
end
