# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::Alerter do
  def event_for(refusal) = {name: refusal.class.name, payload: refusal, context: {}, tags: {}}

  it "alerts when the upstream served a page outside the perimeter, naming the page and what was dropped" do
    refusal = Portail::Access::Refusal.new(reason: :upstream_mismatch, path: "/demarches",
      membership_id: "m-1", dropped_ids: ["d-1", "d-2"])
    expect(Sentry).to receive(:capture_message).with(
      "Périmètre non respecté par l'amont sur /demarches : 2 éléments hors périmètre retirés de la page",
      level: :warning, extra: {membership_id: "m-1", dropped_ids: ["d-1", "d-2"]}
    )

    described_class.new.emit(event_for(refusal))
  end

  it "writes the singular for a single element" do
    refusal = Portail::Access::Refusal.new(reason: :upstream_mismatch, path: "/demarches",
      membership_id: "m-1", dropped_ids: ["d-1"])
    expect(Sentry).to receive(:capture_message)
      .with(a_string_including("1 élément hors périmètre retiré de la page"),
        level: :warning, extra: {membership_id: "m-1", dropped_ids: ["d-1"]})

    described_class.new.emit(event_for(refusal))
  end

  # Un refus qui fonctionne n'est pas une panne.
  it "stays silent on a policy refusal" do
    refusal = Portail::Access::Refusal.new(reason: :out_of_perimeter, path: "/demarches/x")
    expect(Sentry).not_to receive(:capture_message)

    described_class.new.emit(event_for(refusal))
  end
end
