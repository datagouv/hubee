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

  describe Portail::DataStream::V1Rules do
    def v1_attachment_rules(**) = build(:portail_data_stream_v1_rules, **)

    it "accepts a piece from a state the data stream lists" do
      expect(v1_attachment_rules(attachment_states: %w[in_progress]).attachable_from?("in_progress")).to be(true)
    end

    it "refuses a piece from a state the data stream does not list" do
      expect(v1_attachment_rules(attachment_states: %w[in_progress]).attachable_from?("acknowledged")).to be(false)
    end

    it "refuses any piece when no format is accepted" do
      expect(v1_attachment_rules(attachment_content_types: []).attachable_from?("in_progress")).to be(false)
    end

    it "refuses any piece when the maximum size is zero" do
      expect(v1_attachment_rules(attachment_max_byte_size: 0).attachable_from?("in_progress")).to be(false)
    end

    it "compares content types exactly" do
      rules = v1_attachment_rules(attachment_content_types: ["application/pdf"])

      expect(rules.accepts_content_type?("application/pdf")).to be(true)
      expect(rules.accepts_content_type?("Application/PDF")).to be(false)
    end

    it "accepts a size up to the maximum, bound included" do
      rules = v1_attachment_rules(attachment_max_byte_size: 100)

      expect(rules.accepts_byte_size?(100)).to be(true)
      expect(rules.accepts_byte_size?(101)).to be(false)
    end
  end
end
