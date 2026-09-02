# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Agents::Create::FindOrCreateOrganizationLinks do
  subject(:result) { described_class.call(payload: payload) }

  let(:payload) do
    API::AgentPayload.new(memberships: [{siret: "21750056000016", insee_code: "001", role: "member"}])
  end

  context "when the link already exists" do
    it "reuses it without asking the referential" do
      link = create(:organization_link, siret: "21750056000016", insee_code: "001")
      allow(API::Referential::Organization).to receive(:find)

      expect(result).to be_success
      expect(result.organization_links).to eq({"21750056000016" => link})
      expect(API::Referential::Organization).not_to have_received(:find)
    end
  end

  context "when the payload carries several memberships" do
    let(:payload) do
      API::AgentPayload.new(memberships: [
        {siret: "21750056000016", insee_code: "001", role: "member"},
        {siret: "35600000000048", insee_code: "002", role: "member"}
      ])
    end

    it "resolves one link per siret" do
      first_link = create(:organization_link, siret: "21750056000016", insee_code: "001")
      second_link = create(:organization_link, siret: "35600000000048", insee_code: "002")

      expect(result).to be_success
      expect(result.organization_links).to eq(
        "21750056000016" => first_link, "35600000000048" => second_link
      )
    end
  end

  context "when the link does not exist" do
    it "creates it once the referential confirms the organization" do
      allow(API::Referential::Organization).to receive(:find)
        .with(siret: "21750056000016", insee_code: "001")
        .and_return(API::Referential::Organization::Record.new(
          siret: "21750056000016", insee_code: "001", name: "Mairie de Paris 6e"
        ))

      expect(result).to be_success
      expect(result.organization_links["21750056000016"])
        .to have_attributes(siret: "21750056000016", insee_code: "001")
    end

    it "refuses an organization the referential does not know, writing nothing" do
      allow(API::Referential::Organization).to receive(:find)
        .and_raise(API::Referential::Organization::NotFound)

      expect(result).to be_failure
      expect(result.error).to eq(:organization_unknown)
      expect(result.membership_index).to eq(0)
      expect(OrganizationLink.count).to eq(0)
    end

    it "reports an unavailable referential without alerting supervision" do
      allow(API::Referential::Organization).to receive(:find)
        .and_raise(API::Referential::Organization::Unavailable)
      allow(Rails.error).to receive(:report)

      expect(result).to be_failure
      expect(result.error).to eq(:referential_unavailable)
      expect(Rails.error).not_to have_received(:report)
    end

    it "alerts supervision about an inconsistent referential, as the same failure for the caller" do
      allow(API::Referential::Organization).to receive(:find)
        .and_raise(API::Referential::Organization::Inconsistent)
      allow(Rails.error).to receive(:report)

      expect(result).to be_failure
      expect(result.error).to eq(:referential_unavailable)
      expect(Rails.error).to have_received(:report)
        .with(instance_of(API::Referential::Organization::Inconsistent), hash_including(handled: true))
    end

    it "recovers the link a concurrent call just created, inside the surrounding transaction" do
      link = create(:organization_link, siret: "21750056000016", insee_code: "001")
      first_lookup_done = false
      allow(OrganizationLink).to receive(:find_by).and_wrap_original do |original, *args|
        if first_lookup_done
          original.call(*args)
        else
          first_lookup_done = true
          nil
        end
      end
      # Le check applicatif d'unicité est lui-même racé en production (deux connexions
      # distinctes) : on le neutralise pour laisser l'index PostgreSQL, seule source de
      # vérité, rejeter l'insertion en doublon pour de vrai.
      allow_any_instance_of(OrganizationLink).to receive(:valid?).and_return(true)
      allow(API::Referential::Organization).to receive(:find)

      result = ActiveRecord::Base.transaction { described_class.call(payload: payload) }

      expect(result).to be_success
      expect(result.organization_links.values).to contain_exactly(link)
    end
  end
end
