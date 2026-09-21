# frozen_string_literal: true

require "rails_helper"

# Le périmètre du portail, pas celui d'un rattachement : ce qu'il ne sert pas, HubEE le supervise.
RSpec.describe Portail::Access::StatePerimeter do
  it "covers each state the portal serves" do
    served = %w[transmitted acknowledged in_progress awaiting_attachments done refused closed]

    expect(served.map { |state| described_class.covers?(state) }).to all(be(true))
  end

  # Le service instructeur n'est pas responsable de cet état : HubEE, tiers de transmission,
  # remet lui-même ces télédossiers à « transmise ».
  it "leaves the integration error to HubEE" do
    expect(described_class.covers?("integration_error")).to be(false)
  end

  # Liste fermée : un état que l'amont ajouterait n'entre pas sans décision du portail.
  it "does not cover a state the upstream would add, nor a missing one" do
    expect(described_class.covers?("inconnu")).to be(false)
    expect(described_class.covers?(nil)).to be(false)
  end
end
