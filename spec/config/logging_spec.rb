# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Structured logging configuration" do
  it "formats every log through the logfmt formatter recommended by the CSIRT" do
    formatters = SemanticLogger.appenders.map(&:formatter)

    expect(formatters).to all(be_a(SemanticLogger::Formatters::Logfmt))
  end
end
