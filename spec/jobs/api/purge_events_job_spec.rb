# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::PurgeEventsJob do
  describe "#perform" do
    it "removes what has passed the retention and leaves the rest" do
      expired = create(:event, created_at: Event::RETENTION.ago - 1.day)
      kept = create(:event, created_at: Event::RETENTION.ago + 1.day)

      described_class.perform_now

      expect(Event.all).to contain_exactly(kept)
      expect { expired.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
