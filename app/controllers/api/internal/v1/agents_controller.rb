# frozen_string_literal: true

module API
  module Internal
    module V1
      class AgentsController < API::Internal::V1::BaseController
        REFUSALS = {
          already_attached: {attribute: :email, status: :conflict},
          siret_already_attached: {attribute: :insee_code, status: :conflict},
          unknown_organization: {attribute: :siret, status: :unprocessable_content},
          unknown_data_stream: {attribute: :data_stream_codes, status: :unprocessable_content}
        }.freeze

        # Sans quoi Rails envelopperait lui-même un payload qui a oublié la clé `agent`.
        wrap_parameters false

        before_action :authorize_registration
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

        def authorize_registration = authorize(:agent, :create?, policy_class: AgentPolicy)

        def agent_params
          params.expect(agent: [
            :email, :first_name, :last_name, :civility,
            membership: [:siret, :insee_code, :role, :job_title, :phone_number, :mobile_phone_number]
          ]).to_h.deep_symbolize_keys.deep_merge(membership: data_stream_codes_param).merge(send_invitation_param)
        end

        # Lus dans le JSON brut : les paramètres de Rails font de [null] une liste vide, et leur filtrage
        # écarte une liste mal formée. L'une ou l'autre donnerait tous les flux à un administrateur
        # local ; le form refuse ce qui n'est pas une liste de chaînes, et une liste absente. Hors d'un
        # corps JSON objet (l'agent peut venir de l'URL), la liste est absente.
        def data_stream_codes_param
          membership = raw_agent["membership"]
          return {} unless membership.is_a?(Hash) && membership.key?("data_stream_codes")

          {data_stream_codes: membership["data_stream_codes"]}
        end

        # Lue dans le JSON brut, comme data_stream_codes : le filtrage de Rails écarterait une valeur non
        # scalaire avant que le form ne la refuse. Hors d'un corps JSON objet, elle est absente, donc fausse.
        def send_invitation_param
          raw_agent.slice("send_invitation").symbolize_keys
        end

        def raw_agent
          @raw_agent ||= begin
            body = JSON.parse(request.raw_post) if request.media_type == Mime[:json]
            agent = body["agent"] if body.is_a?(Hash)
            agent.is_a?(Hash) ? agent : {}
          rescue JSON::ParserError
            {}
          end
        end

        # Un refus est un motif, ou un motif et les paramètres de son message. Un conflit
        # l'emporte ; l'indisponibilité seule n'est rendue que sans aucun motif.
        def render_refusal(form, refusals)
          refusals.each { |reason, options = {}| form.errors.add(REFUSALS.fetch(reason)[:attribute], reason, **options) }

          if form.errors.empty?
            render json: {error: "service_unavailable", message: I18n.t("api.internal.v1.agents.unavailable")}, status: :service_unavailable
          elsif refusals.any? { |reason, _| REFUSALS.fetch(reason)[:status] == :conflict }
            render json: form.error_details, status: :conflict
          else
            render json: form.error_details, status: :unprocessable_content
          end
        end

        def missing_envelope
          render json: {error: "missing_agent", message: I18n.t("api.internal.v1.agents.missing_envelope")}, status: :bad_request
        end
      end
    end
  end
end
