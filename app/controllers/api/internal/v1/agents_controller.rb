# frozen_string_literal: true

module API
  module Internal
    module V1
      class AgentsController < API::Internal::V1::BaseController
        REFUSALS = {
          already_attached: {attribute: :email, status: :conflict},
          email_taken: {attribute: :email, status: :conflict},
          siret_already_attached: {attribute: :insee_code, status: :conflict},
          unknown_organization: {attribute: :siret, status: :unprocessable_content},
          unknown_data_stream: {attribute: :data_stream_codes, status: :unprocessable_content}
        }.freeze

        # Sans quoi Rails envelopperait lui-même un payload qui a oublié la clé `agent`.
        wrap_parameters false

        # L'autorisation passe avant la recherche : un client sans le droit reçoit 403 même sur un agent inconnu.
        before_action :authorize_agent
        before_action :set_agent, only: %i[show update destroy]
        rescue_from ActionController::ParameterMissing, with: :missing_envelope

        # La chaîne de requête seule : un corps de GET n'a pas à compter. Pagy compose les liens de l'en-tête Link
        # avec les paramètres que le form a validés.
        def index
          form = AgentSearchForm.from_query(request.query_parameters)
          result = Agents::Index.call(form:)
          return render json: form.error_details, status: :unprocessable_content unless result.success?

          link_request = {base_url: request.base_url, path: request.path, params: form.pagination_link_params}
          @pagy, @agents = pagy(result.agents, page: form.pagination[:page], request: link_request)
        end

        def show
        end

        def create
          form = AgentForm.new(**agent_params, **source_info_param)
          result = Agents::Create.call(form:, api_client: current_api_client, request_id: request.request_id)

          if result.success?
            @membership = result.membership
            render :create, status: :created
          else
            render_refusal(form, Array(result.refusals))
          end
        end

        def update
          form = AgentUpdateForm.new(agent: @agent, **correction_params)
          result = Agents::Update.call(form:, api_client: current_api_client, request_id: request.request_id)

          if result.success?
            # L'état enregistré : les rattachements rechargés, aucune valeur de la requête n'est renvoyée telle quelle.
            @agent = Agent.includes(memberships: %i[organization_link data_stream_accesses]).find(@agent.id)
            render :update
          else
            render_refusal(form, Array(result.refusals))
          end
        end

        def destroy
          Agents::Destroy.call!(agent: @agent, api_client: current_api_client, request_id: request.request_id)

          head :no_content
        end

        private

        # Pundit juge la question de l'action : `index?`, `show?`, `create?`, `update?` ou `destroy?`.
        def authorize_agent = authorize(:agent, policy_class: AgentPolicy)

        # Les rattachements, leur organisation et leurs flux d'un coup : la représentation les parcourt tous.
        def set_agent
          @agent = Agent.includes(memberships: %i[organization_link data_stream_accesses]).find(params[:id])
        end

        # Lus dans le JSON brut : le filtrage de Rails écarterait en silence une valeur non scalaire, que le
        # form doit refuser. Prénom et nom, comme toute clé inconnue, sont écartés ; une enveloppe qui n'en
        # porte aucune autre ne change rien. Seule l'absence de l'objet `agent` est une demande mal formée.
        def correction_params
          agent = raw_body["agent"]
          raise ActionController::ParameterMissing, :agent unless agent.is_a?(Hash)

          agent.slice(*AgentUpdateForm::CORRECTABLE_ATTRIBUTES.map(&:to_s)).symbolize_keys
        end

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

        def source_info_param
          raw_body.slice("source_info").symbolize_keys
        end

        def raw_agent
          agent = raw_body["agent"]
          agent.is_a?(Hash) ? agent : {}
        end

        def missing_envelope
          render json: {error: "missing_agent", message: I18n.t("api.internal.v1.agents.missing_envelope")}, status: :bad_request
        end
      end
    end
  end
end
