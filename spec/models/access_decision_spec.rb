# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccessDecision, type: :model do
  describe "outcome" do
    it "accepts the closed list and nothing else" do
      expect(build(:access_decision, outcome: "granted")).to be_valid
      expect(build(:access_decision, outcome: "denied")).to be_valid
      expect(build(:access_decision, outcome: "maybe")).not_to be_valid
    end
  end

  # La rétention est une décision de sécurité : elle vit dans une constante pour se changer
  # en une ligne, et le scope doit la suivre plutôt que de redire six mois.
  describe ".expired" do
    it "gathers exactly what has passed the retention" do
      old = create(:access_decision, created_at: described_class::RETENTION.ago - 1.day)
      create(:access_decision, created_at: described_class::RETENTION.ago + 1.day)

      expect(described_class.expired).to contain_exactly(old)
    end
  end
end
