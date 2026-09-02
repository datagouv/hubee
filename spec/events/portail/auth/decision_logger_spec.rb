# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Auth::DecisionLogger do
  # Deux abonnés, deux politiques opposées sur la même décision : le journal masque ce que
  # la table conserve. C'est ce que l'objet d'événement rend possible.
  it "hands the decision to the logger as fields, masking what a log must not carry" do
    decision = Portail::Auth::Decision.new(outcome: :denied, reason: :unknown_agent,
      email: "agent@example.gouv.fr", provider_sub: "sub-abc", siret: "13002526500013")
    event = {name: decision.class.name, payload: decision,
             context: {ip_address: "203.0.113.7"}, tags: {}}

    expect(Rails.logger).to receive(:info) do |message, fields|
      expect(message).to eq("Décision d'accès")
      expect(fields).to include(event: "Portail::Auth::Decision", outcome: :denied,
        reason: :unknown_agent, siret: "13002526500013", ip_address: "203.0.113.7")
      expect(fields.keys).not_to include(:email, :provider_sub)
    end

    described_class.new.emit(event)
  end
end
