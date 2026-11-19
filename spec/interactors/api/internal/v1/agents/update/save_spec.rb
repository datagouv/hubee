# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Update::Save do
  let(:api_client) { create(:oauth_application, name: "systeme-interne") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr", civility: "ms") }

  describe ".call" do
    def save(**attributes)
      form = API::Internal::V1::AgentUpdateForm.new(agent:, **attributes).tap(&:validate)
      described_class.call(form:, api_client:, request_id: "req-1")
    end

    it "writes the change and its trace in one transaction" do
      result = save(email: "alice.dupont@ville.fr", civility: "mr")

      expect(result).to be_success
      expect(result.changed).to be(true)
      expect(agent.reload).to have_attributes(email: "alice.dupont@ville.fr", civility: "mr")
      expect(Event.sole).to have_attributes(
        event_type: "agent.updated",
        eventable: agent,
        metadata: {
          "api_client" => "systeme-interne",
          "api_client_uid" => api_client.uid,
          "request_id" => "req-1",
          "email" => "alice.dupont@ville.fr",
          "changes" => {
            "email" => ["alice.martin@ville.fr", "alice.dupont@ville.fr"],
            "civility" => ["ms", "mr"]
          }
        }
      )
    end

    # Le controller a lu l'agent ; un autre appel le modifie avant le verrou. L'avant et la trace sont ceux de
    # l'état verrouillé.
    it "computes the changes from the state read under the lock, not the one loaded before" do
      loaded = Agent.find(agent.id)
      agent.update!(civility: "mr")
      form = API::Internal::V1::AgentUpdateForm.new(agent: loaded, civility: "ms").tap(&:validate)

      described_class.call(form:, api_client:, request_id: "req-1")

      expect(agent.reload.civility).to eq("ms")
      expect(Event.sole.metadata["changes"]).to eq("civility" => ["mr", "ms"])
    end

    it "writes nothing when a concurrent call has already made the change" do
      loaded = Agent.find(agent.id)
      agent.update!(civility: "mr")
      form = API::Internal::V1::AgentUpdateForm.new(agent: loaded, civility: "mr").tap(&:validate)

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result.changed).to be(false)
      expect(Event.count).to eq(0)
    end

    it "traces the current address when only the civility changes" do
      save(civility: nil)

      expect(Event.sole.metadata).to include("email" => "alice.martin@ville.fr", "changes" => {"civility" => ["ms", nil]})
    end

    it "keeps the provider subject" do
      agent.update!(provider_sub: "sub-alice")

      save(email: "alice.dupont@ville.fr")

      expect(agent.reload.provider_sub).to eq("sub-alice")
    end

    it "writes nothing when nothing changes" do
      result = save(email: "Alice.Martin@Ville.fr", civility: "ms")

      expect(result).to be_success
      expect(result.changed).to be(false)
      expect(Event.count).to eq(0)
    end

    it "writes nothing when the trace fails" do
      # Comme Rails, l'erreur porte son enregistrement : Save lit ses erreurs pour la laisser passer.
      expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Event.new))

      expect { save(email: "alice.dupont@ville.fr", civility: "mr") }.to raise_error(ActiveRecord::RecordInvalid)

      expect(agent.reload).to have_attributes(email: "alice.martin@ville.fr", civility: "ms")
    end

    # La validation d'unicité d'Agent voit l'adresse avant l'index unique.
    it "refuses an email taken between the check and the write" do
      form = API::Internal::V1::AgentUpdateForm.new(agent:, email: "alice.dupont@ville.fr").tap(&:validate)
      create(:agent, email: "alice.dupont@ville.fr")

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_failure
      expect(result.refusals).to eq([:email_taken])
      expect(agent.reload.email).to eq("alice.martin@ville.fr")
      expect(Event.count).to eq(0)
    end

    it "refuses an email taken in a race on the unique index" do
      form = API::Internal::V1::AgentUpdateForm.new(agent:, email: "alice.dupont@ville.fr").tap(&:validate)
      expect(agent).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_failure
      expect(result.refusals).to eq([:email_taken])
      expect(Event.count).to eq(0)
    end
  end
end
