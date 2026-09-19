# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DataStream do
  describe "#allows?" do
    it "allows a state the upstream lists" do
      expect(build(:portail_data_stream).allows?("awaiting_attachments")).to be(true)
    end

    it "withholds a state the upstream leaves out" do
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(data_stream.allows?("awaiting_attachments")).to be(false)
    end
  end
end
