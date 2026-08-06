# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::AuthenticationLevels do
  # C'est la raison d'être de ce module : les trois listes vivaient séparément et rien
  # n'exprimait qu'elles devaient rester d'accord. Ajouter un niveau MFA doit désormais
  # suffire à le rendre acceptable, sans seconde modification.
  it "derives what it accepts from the floor and the second-factor levels" do
    expect(described_class::ACCEPTED)
      .to eq([described_class::MINIMUM, *described_class::SECOND_FACTOR])
  end

  # Au niveau 0, le lien organisationnel est déclaratif — y compris avec un second
  # facteur. On refuse donc sur le niveau, pas sur l'absence de MFA.
  it "refuses a declarative organisational link, second factor or not" do
    expect(described_class.accepted?("eidas0")).to be(false)
    expect(described_class.accepted?("eidas0-mfa")).to be(false)
    expect(described_class.accepted?("eidas1")).to be(true)
  end

  it "does not count the floor as a second factor" do
    expect(described_class.second_factor?("eidas1")).to be(false)
    expect(described_class.second_factor?("eidas1-mfa")).to be(true)
  end

  # Une élévation qui accepterait encore le plancher enverrait deux consignes
  # contradictoires dans la même requête, et ProConnect ignorerait l'exigence.
  it "drops the floor from what it demands when stepping up" do
    expect(described_class.demanded(step_up: false)).to eq([described_class::MINIMUM])
    expect(described_class.demanded(step_up: true)).not_to include(described_class::MINIMUM)
  end

  it "knows nothing it would not accept" do
    expect(described_class::SECOND_FACTOR).to all(satisfy { described_class.accepted?(it) })
  end
end
