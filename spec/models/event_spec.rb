# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  it "records its subject, type, metadata and date" do
    agent = create(:agent)

    event = create(:event, eventable: agent, event_type: "agent.created",
      metadata: {"email" => agent.email})

    expect(event.reload).to have_attributes(
      eventable_type: "Agent", eventable_id: agent.id, event_type: "agent.created",
      metadata: {"email" => agent.email}, created_at: be_within(1.second).of(Time.current)
    )
  end

  it "refuses any change or removal once written and keeps the trace as it was" do
    event = create(:event, event_type: "agent.created", metadata: {"email" => "a@b.fr"})

    expect { event.update!(event_type: "membership.created") }
      .to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.update_columns(metadata: {}) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(described_class.find(event.id))
      .to have_attributes(event_type: "agent.created", metadata: {"email" => "a@b.fr"})
  end

  # La suppression d'un agent (#992) ne doit ni effacer sa trace ni être bloquée par elle.
  it "outlives the subject it concerns" do
    agent = create(:agent)
    event = create(:event, eventable: agent, metadata: {"email" => agent.email})

    agent.destroy!

    expect(described_class.find(event.id)).to have_attributes(
      eventable_type: "Agent", eventable_id: agent.id, metadata: {"email" => agent.email}
    )
  end

  describe "event_type" do
    it "accepts the closed list and nothing else" do
      expect(build(:event, event_type: "agent.created")).to be_valid
      expect(build(:event, event_type: "membership.created")).to be_valid
      expect(build(:event, event_type: "agent.deleted")).not_to be_valid
    end

    it "records nothing for a type outside the list" do
      expect { create(:event, event_type: "agent_created") }
        .to raise_error(ActiveRecord::RecordInvalid)
      expect(described_class.count).to eq(0)
    end
  end

  describe ".expired" do
    it "gathers exactly what has passed the retention" do
      old = create(:event, created_at: described_class::RETENTION.ago - 1.day)
      create(:event, created_at: described_class::RETENTION.ago + 1.day)

      expect(described_class.expired).to contain_exactly(old)
    end
  end
end
