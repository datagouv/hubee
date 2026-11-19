# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class MembershipsController < API::Internal::V1::BaseController
          REFUSALS = {
            unknown_data_stream: {attribute: :data_stream_codes, status: :unprocessable_content}
          }.freeze

          # L'autorisation passe avant la recherche : un client sans le droit reçoit 403 même sur un
          # rattachement inconnu.
          before_action :authorize_membership, only: %i[update destroy]
          before_action :require_declared_actor, only: %i[update destroy]
          before_action :set_membership, only: %i[update destroy]
          rescue_from ActionController::ParameterMissing, with: :missing_envelope

          def update
            form = MembershipUpdateForm.new(membership: @membership, **update_params)
            result = Memberships::Update.call(form:, **trace_context)

            if result.success?
              # L'état enregistré : aucune valeur de la requête n'est renvoyée telle quelle.
              @membership = Membership.includes(:organization_link, :data_stream_accesses).find(@membership.id)
              render :update
            else
              render_refusal(form, Array(result.refusals))
            end
          end

          def destroy
            Memberships::Destroy.call!(membership: @membership, **trace_context)

            head :no_content
          end

          private

          # Retirer un rattachement est une modification de l'agent : Pundit juge `update?` ou `destroy?`, au même droit.
          def authorize_membership = authorize(:membership, policy_class: MembershipPolicy)

          # Cherché parmi les rattachements de l'agent : celui d'un autre agent est introuvable.
          def set_membership
            @agent = Agent.find(params[:agent_id])
            @membership = @agent.memberships.includes(:organization_link, :data_stream_accesses).find(params[:id])
          end

          # Lus dans le JSON brut : les paramètres de Rails font de [null] une liste vide, et leur filtrage
          # écarte en silence une valeur non scalaire. Une liste vide donnerait tous les flux à un
          # administrateur local ; le form refuse ce qui n'est pas une liste de chaînes, et une valeur non
          # scalaire, drapeau `all_data_streams` compris, et l'organisation. Toute autre clé est écartée ; une
          # enveloppe qui n'en porte aucune ne change rien. Seule l'absence de l'objet `membership` est une
          # demande mal formée.
          def update_params
            membership = raw_body["membership"]
            raise ActionController::ParameterMissing, :membership unless membership.is_a?(Hash)

            membership.slice(*MembershipUpdateForm::ACCEPTED_KEYS.map(&:to_s)).symbolize_keys
          end

          def missing_envelope
            render json: {error: "missing_membership", message: I18n.t("api.internal.v1.memberships.missing_envelope")}, status: :bad_request
          end
        end
      end
    end
  end
end
