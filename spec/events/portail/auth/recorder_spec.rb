# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Auth::Recorder do
  def event_for(decision, context: {})
    {name: decision.class.name, payload: decision, context:, tags: {}}
  end

  it "writes one row per decision" do
    decision = Portail::Auth::Decision.new(outcome: :denied, reason: :unknown_agent,
      email: "agent@example.gouv.fr", siret: "13002526500013")

    expect { described_class.new.emit(event_for(decision)) }
      .to change(AccessDecision, :count).by(1)

    expect(AccessDecision.last).to have_attributes(outcome: "denied", reason: "unknown_agent",
      email: "agent@example.gouv.fr", siret: "13002526500013")
  end

  # Ce que le Hash aurait masqué. Sans cet exemple, un retour en arrière sur la forme de
  # l'événement remplirait la table de « [FILTERED] » sans que rien n'échoue.
  it "keeps the address and the pseudonymous id unmasked" do
    decision = Portail::Auth::Decision.new(outcome: :granted,
      email: "agent@example.gouv.fr", provider_sub: "sub-abc")

    described_class.new.emit(event_for(decision))

    expect(AccessDecision.last).to have_attributes(email: "agent@example.gouv.fr",
      provider_sub: "sub-abc")
  end

  # L'IP n'est portée par aucun point d'émission : elle arrive par le contexte de la requête.
  it "takes the request context from the event, not from its payload" do
    context = {ip_address: "203.0.113.7", user_agent: "Firefox", request_id: "req-1"}

    described_class.new.emit(event_for(Portail::Auth::Decision.new(outcome: :granted), context:))

    expect(AccessDecision.last).to have_attributes(ip_address: "203.0.113.7",
      user_agent: "Firefox", request_id: "req-1")
  end
end
