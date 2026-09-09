# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::HubAPI::CalendarDay do
  describe ".parse!" do
    it "reads a calendar day written YYYY-MM-DD" do
      expect(described_class.parse!("2026-08-31")).to eq(Date.new(2026, 8, 31))
    end

    # Forme, calendrier et siècle, plus la chaîne trop longue qui faisait lever `Date.iso8601`
    # hors Date::Error.
    it "refuses anything else, an unreadable or absurd date included" do
      unreadable = ["31/08/2026", "2026-213", "20260801", "2026-02-30", "0000-01-01", "2126-01-01",
        "2026-08-01#{"x" * 200}", ""]

      unreadable.each do |value|
        expect { described_class.parse!(value) }.to raise_error(Portail::HubAPI::InvalidRequest), value
      end
    end
  end
end
