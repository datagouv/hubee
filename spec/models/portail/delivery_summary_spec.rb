# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliverySummary do
  # La forme liste et la forme détail portent les mêmes champs communs : leur affichage doit
  # rester en parité. Sans cet exemple, la liste pourrait diverger du détail sans bruit.
  describe "display methods" do
    it "carries the same display contract as the detail form" do
      summary = build(:portail_delivery_summary, state: "transmitted",
        transmitted_at: nil, updated_at: nil)

      expect(summary.display_state).to eq("Transmise")
      expect(summary.display_transmitted_at).to eq("—")
      expect(summary.display_updated_at).to eq("—")
    end
  end
end
