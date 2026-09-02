# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::AgentPayload do
  subject(:payload) { described_class.new(attributes) }

  let(:attributes) do
    {
      email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms",
      memberships: [{
        siret: "21750056000016", insee_code: "001", role: "local_administrator",
        job_title: "Officier d'état civil", phone_number: "+33123456789"
      }]
    }
  end

  it "accepts a complete payload" do
    expect(payload).to be_valid
  end

  it "accepts a payload without the optional civility" do
    attributes.delete(:civility)

    expect(payload).to be_valid
  end

  it "accepts several memberships of different sirets" do
    attributes[:memberships] << {siret: "35600000000048", insee_code: "002", role: "member"}

    expect(payload).to be_valid
  end

  # Le controller passe des ActionController::Parameters permis, pas des hashs
  # bruts : le writer doit construire les MembershipPayload depuis chaque entrée.
  it "builds itself from permitted controller params, memberships included" do
    params = ActionController::Parameters.new(attributes).permit!

    expect(described_class.new(params)).to be_valid
  end

  %i[email first_name last_name].each do |required|
    it "refuses a payload without #{required}" do
      attributes[required] = nil

      expect(payload).not_to be_valid
      expect(payload.errors).to be_of_kind(required, :blank)
    end
  end

  it "refuses an address that is not an email" do
    attributes[:email] = "pas-une-adresse"

    expect(payload).not_to be_valid
  end

  it "refuses a civility outside the closed list" do
    attributes[:civility] = "dr"

    expect(payload).not_to be_valid
  end

  it "refuses a payload without any membership" do
    attributes[:memberships] = []

    expect(payload).not_to be_valid
    expect(payload.errors).to be_of_kind(:memberships, :blank)
  end

  it "refuses an invalid membership, naming the field by index" do
    attributes[:memberships][0][:siret] = "123"

    expect(payload).not_to be_valid
    expect(payload.errors).to be_of_kind(:"memberships[0].siret", :invalid)
  end

  it "refuses two memberships sharing the same siret" do
    attributes[:memberships] << {siret: "21750056000016", insee_code: "002", role: "member"}

    expect(payload).not_to be_valid
    expect(payload.errors).to be_of_kind(:memberships, :duplicated_siret)
  end
end
