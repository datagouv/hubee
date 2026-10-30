# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::CheckMemberships do
  describe ".call" do
    def validated_form(**attributes)
      build(:api_internal_agent_form, **attributes).tap(&:validate)
    end

    def attach(email:, siret:, insee_code:)
      agent = Agent.find_by(email:) || create(:agent, email:)
      create(:membership, agent:, organization_link: create(:organization_link, siret:, insee_code:))
    end

    it "refuses an agent already attached to this organisation" do
      attach(email: "alice.martin@ville.fr", siret: "21750056000016", insee_code: "75056")

      result = described_class.call(form: validated_form(email: "alice.martin@ville.fr"))

      expect(result).to be_success
      expect(result.refusals).to eq([:already_attached])
    end

    it "recognizes the agent whatever the case of the address" do
      attach(email: "alice.martin@ville.fr", siret: "21750056000016", insee_code: "75056")

      result = described_class.call(form: validated_form(email: "Alice.Martin@Ville.FR"))

      expect(result.refusals).to eq([:already_attached])
    end

    # La connexion choisit le rattachement d'après le seul SIRET.
    it "refuses another insee code on a SIRET the agent is already attached to" do
      attach(email: "alice.martin@ville.fr", siret: "21750056000016", insee_code: "75101")

      result = described_class.call(form: validated_form(email: "alice.martin@ville.fr"))

      expect(result.refusals).to eq([:siret_already_attached])
    end

    it "lets an agent known for another SIRET through" do
      attach(email: "alice.martin@ville.fr", siret: "13002526500013", insee_code: "75056")

      result = described_class.call(form: validated_form(email: "alice.martin@ville.fr"))

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end

    it "lets an unknown agent through" do
      result = described_class.call(form: validated_form)

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end

    # Sans adresse ni SIRET valides, il n'y a rien à rapprocher : leur motif est déjà posé.
    it "does not look for an attachment on an invalid field" do
      attach(email: "alice.martin@ville.fr", siret: "21750056000016", insee_code: "75056")

      result = described_class.call(form: validated_form(email: "alice.martin@ville.fr", insee_code: ""))

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end
  end
end
