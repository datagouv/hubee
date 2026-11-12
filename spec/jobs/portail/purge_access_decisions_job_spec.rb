# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::PurgeAccessDecisionsJob do
  # La rétention est une obligation, pas un confort : ce qui dépasse doit disparaître, et
  # rien d'autre. La durée est écrite en dur, et non lue dans la constante : c'est la
  # décision elle-même que cette spec épingle.
  it "removes what is older than one year and keeps the rest" do
    old = create(:access_decision, created_at: 1.year.ago - 1.day)
    kept = create(:access_decision, created_at: 1.year.ago + 1.day)

    described_class.perform_now

    expect(AccessDecision.exists?(old.id)).to be(false)
    expect(AccessDecision.exists?(kept.id)).to be(true)
  end
end
