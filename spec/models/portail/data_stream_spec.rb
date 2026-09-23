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

    it "allows a piece from a state the data stream lists" do
      rules = v1_attachment_rules(states_allowing_attachment: %w[in_progress])

      expect(rules.allows_attachment_from?("in_progress")).to be(true)
    end

    it "refuses a piece from a state the data stream does not list" do
      rules = v1_attachment_rules(states_allowing_attachment: %w[in_progress])

      expect(rules.allows_attachment_from?("acknowledged")).to be(false)
    end

    # Le type et la taille se confrontent au fichier choisi, pas à l'état.
    it "allows a piece from a listed state whatever the formats and size" do
      rules = v1_attachment_rules(attachment_content_types: [], attachment_max_byte_size: 0)

      expect(rules.allows_attachment_from?("in_progress")).to be(true)
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
