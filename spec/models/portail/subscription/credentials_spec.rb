# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription::Credentials do
  describe "#client_secret" do
    it "keeps the secret readable through its accessor" do
      credentials = described_class.new(client_id: "client-42", client_secret: "s3cr3t")

      expect(credentials.client_secret).to eq("s3cr3t")
    end
  end

  # Tout ce qui finit dans un journal ou un rapport d'erreur passe par l'une de ces sorties.
  describe "text representations" do
    it "masks the secret and keeps the client id" do
      credentials = described_class.new(client_id: "client-42", client_secret: "s3cr3t")

      outputs = {
        "inspect" => credentials.inspect,
        "to_s" => credentials.to_s,
        "to_h" => credentials.to_h.to_s,
        "pretty_inspect" => credentials.pretty_inspect
      }

      outputs.each do |name, output|
        expect(output).to include("client-42", "[FILTERED]"), name
        expect(output).not_to include("s3cr3t"), name
      end
    end
  end
end
