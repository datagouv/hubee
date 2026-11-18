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

  # Une réauthentification juge le même retour ProConnect qu'une connexion : sans ce champ, rien ne
  # les distinguerait dans la table.
  it "records the kind of the decision" do
    described_class.new.emit(event_for(Portail::Auth::Decision.new(outcome: :granted, kind: :reauthentication)))

    expect(AccessDecision.last.kind).to eq("reauthentication")
  end

  it "records a sign-in by default" do
    described_class.new.emit(event_for(Portail::Auth::Decision.new(outcome: :granted)))

    expect(AccessDecision.last.kind).to eq("sign_in")
  end
end
