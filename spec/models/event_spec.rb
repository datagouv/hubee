# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  it_behaves_like "a model with UUID v7 primary key"

  describe "event_type" do
    it "accepts the closed list and nothing else" do
      expect(build(:event, event_type: "agent.created")).to be_valid
      expect(build(:event, event_type: "membership.detached")).to be_valid
      expect(build(:event, event_type: "agent.deleted")).not_to be_valid
    end
  end

  describe "metadata" do
    it "refuses a trace that does not name the system that wrote it" do
      expect(build(:event, metadata: {"subject" => {"email" => "agent@ville.fr"}})).not_to be_valid
    end

    it "refuses a trace that does not identify its subject" do
      expect(build(:event, metadata: {"api_client" => "hub-api"})).not_to be_valid
    end

    it "refuses an update trace that does not say what it changed" do
      metadata = {"api_client" => "hub-api", "subject" => {"email" => "agent@ville.fr"}}

      expect(build(:event, event_type: "agent.updated", metadata: metadata)).not_to be_valid
    end

    it "accepts an update trace that says what it changed" do
      metadata = {
        "api_client" => "hub-api",
        "subject" => {"email" => "agent@ville.fr"},
        "changes" => {"email" => ["agent@ancien.fr", "agent@ville.fr"]}
      }

      expect(build(:event, event_type: "agent.updated", metadata: metadata)).to be_valid
    end
  end

  describe "the subject it describes" do
    it "always names its subject" do
      expect(build(:event, eventable: nil)).not_to be_valid
    end

    # Sans clé étrangère, la trace survit à ce qu'elle décrit — c'est tout son intérêt le jour
    # où l'on cherche qui a détaché un agent.
    it "outlives the record it describes" do
      agent = create(:agent)
      event = described_class.record!(agent, type: "agent.created", metadata: {"api_client" => "hub-api", "subject" => {"email" => agent.email}})

      agent.destroy!

      expect(event.reload.metadata).to eq("api_client" => "hub-api", "subject" => {"email" => agent.email})
    end
  end

  describe "immutability" do
    it "refuses to be rewritten once persisted" do
      event = create(:event)

      expect { event.update!(event_type: "membership.detached") }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe ".record!" do
    it "writes the subject, the type and the facts in one call" do
      agent = create(:agent)

      event = described_class.record!(agent, type: "agent.created", metadata: {"api_client" => "hub-api", "subject" => {"email" => agent.email}})

      expect(event).to have_attributes(
        eventable: agent,
        event_type: "agent.created",
        metadata: {"api_client" => "hub-api", "subject" => {"email" => agent.email}}
      )
    end

    it "refuses a type outside the closed list rather than writing an untraceable row" do
      agent = create(:agent)
      metadata = {"api_client" => "hub-api", "subject" => {"email" => agent.email}}

      expect { described_class.record!(agent, type: "agent.invented", metadata: metadata) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # La rétention est une décision de sécurité : elle vit dans une constante pour se changer en
  # une ligne, et le scope doit la suivre plutôt que de redire trois ans.
  describe ".expired" do
    it "gathers exactly what has passed the retention" do
      old = create(:event, created_at: described_class::RETENTION.ago - 1.day)
      create(:event, created_at: described_class::RETENTION.ago + 1.day)

      expect(described_class.expired).to contain_exactly(old)
    end
  end
end
