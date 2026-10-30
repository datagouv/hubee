# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::PurgeEventsJob do
  it "removes what has passed the retention and keeps the rest" do
    old = create(:event, created_at: Event::RETENTION.ago - 1.day)
    kept = create(:event, created_at: Event::RETENTION.ago + 1.day)
    unrelated = create(:access_decision, created_at: Event::RETENTION.ago - 1.day)

    described_class.perform_now

    expect(Event.all).to contain_exactly(kept)
    expect(AccessDecision.all).to contain_exactly(unrelated)
    expect(Agent.all).to contain_exactly(old.eventable, kept.eventable)
  end
end
