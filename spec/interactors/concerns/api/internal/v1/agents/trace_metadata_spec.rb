# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::TraceMetadata do
  # Une étape minimale qui expose ce que le concern lui donne.
  let(:step) do
    Class.new do
      include Interactor
      include API::Internal::V1::Agents::TraceMetadata

      def call
        context.actor = actor_metadata
        context.reference = membership_reference(context.membership) if context.membership
      end
    end
  end

  let(:api_client) { create(:oauth_application, name: "admin-portal") }

  describe "#actor_metadata" do
    it "names the client, the request and the declared actor" do
      result = step.call(api_client:, request_id: "req-42", declared_actor: "admin-national-42")

      expect(result.actor).to eq(
        api_client: "admin-portal", api_client_uid: api_client.uid, request_id: "req-42", declared_actor: "admin-national-42"
      )
    end

    # Une trace sans acteur déclaré n'en porte pas la clé : pas de null qui laisserait croire à un oubli de l'API.
    it "leaves out the declared actor when the client declared none" do
      result = step.call(api_client:, request_id: "req-42", declared_actor: nil)

      expect(result.actor).to eq(api_client: "admin-portal", api_client_uid: api_client.uid, request_id: "req-42")
    end
  end

  describe "#membership_reference" do
    it "designates the membership by the email of the agent, the SIRET and the insee code" do
      membership = create(
        :membership,
        agent: create(:agent, email: "alice.martin@ville.fr"),
        organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75056")
      )

      result = step.call(api_client:, request_id: "req-42", membership:)

      expect(result.reference).to eq(email: "alice.martin@ville.fr", siret: "21750056000016", insee_code: "75056")
    end
  end
end
