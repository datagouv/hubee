# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::PurgeAccessDecisionsJob do
  # La rétention est une obligation, pas un confort : ce qui dépasse doit disparaître, et
  # rien d'autre.
  it "removes what has passed the retention and keeps the rest" do
    old = create(:access_decision, created_at: AccessDecision::RETENTION.ago - 1.day)
    kept = create(:access_decision, created_at: AccessDecision::RETENTION.ago + 1.day)

    described_class.perform_now

    expect(AccessDecision.exists?(old.id)).to be(false)
    expect(AccessDecision.exists?(kept.id)).to be(true)
  end
end
