# frozen_string_literal: true

require "rails_helper"

RSpec.describe LogfmtFormatter do
  subject(:line) { described_class.new.call(log, SemanticLogger::Appender::IO.new(StringIO.new)) }

  let(:log) do
    SemanticLogger::Log.new("Portail::Sessions::Create::ExchangeCode", :error).tap do |log|
      log.assign(message: "ProConnect indisponible", exception: RuntimeError.new("Connection refused"))
    end
  end

  it "keeps the line's own message and name beside the exception" do
    expect(line).to include('name="Portail::Sessions::Create::ExchangeCode"')
    expect(line).to include('message="ProConnect indisponible"')
    expect(line).to include('exception_class="RuntimeError"')
    expect(line).to include('exception_message="Connection refused"')
    expect(line).to include('tag="exception"')
  end

  it "formats the application's log lines" do
    expect(SemanticLogger.appenders.map(&:formatter)).to all(be_a(described_class))
  end
end
