# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::Register do
  let(:api_client) { create(:oauth_application, name: "systeme-interne") }

  describe ".call" do
    def register(form)
      described_class.call(form: form.tap(&:validate), api_client:, request_id: "req-1")
    end

    def granted(form)
      {
        "api_client" => "systeme-interne",
        "api_client_uid" => api_client.uid,
        "request_id" => "req-1",
        "email" => form.email,
        "siret" => form.siret,
        "insee_code" => form.insee_code,
        "role" => form.role,
        "data_stream_codes" => form.data_stream_codes
      }
    end

    it "writes a new agent, his organisation, his membership, his habilitations and their traces" do
      form = build(:api_internal_agent_form, email: "alice.martin@ville.fr", civility: "ms",
        job_title: "Officier d'état civil", phone_number: "+33123456789", mobile_phone_number: "+33612345678",
        data_stream_codes: ["CERTDC", "AEC"])

      result = register(form)

      expect(result).to be_success
      membership = result.membership
      expect(membership.agent).to have_attributes(
        email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", civility: "ms", provider_sub: nil
      )
      expect(membership.organization_link).to have_attributes(siret: "21750056000016", insee_code: "75056")
      expect(membership).to have_attributes(
        role: "member", job_title: "Officier d'état civil",
        phone_number: "+33123456789", mobile_phone_number: "+33612345678"
      )
      expect(membership.reload.data_stream_codes).to contain_exactly("CERTDC", "AEC")
      expect(Event.order(:created_at).pluck(:event_type, :eventable_type, :eventable_id, :metadata)).to eq([
        ["agent.created", "Agent", membership.agent_id, granted(form)],
        ["membership.created", "Membership", membership.id, granted(form)]
      ])
    end

    # L'identité est rafraîchie par ProConnect à la connexion, l'enregistrement ne la corrige pas.
    it "attaches an agent known for another SIRET, his identity unchanged, tracing the membership only" do
      agent = create(:agent, email: "alice.martin@ville.fr", first_name: "Alicia", last_name: "Martin-Durand")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "13002526500013"))
      form = build(:api_internal_agent_form, email: "alice.martin@ville.fr", civility: "ms")

      result = nil
      expect { result = register(form) }.not_to change(Agent, :count)

      expect(result.membership.agent).to eq(agent)
      expect(agent.reload).to have_attributes(first_name: "Alicia", last_name: "Martin-Durand", civility: nil)
      expect(Event.pluck(:event_type, :eventable_id)).to eq([["membership.created", result.membership.id]])
    end

    it "attaches the agent to an organisation the V2 already knows, without a second link" do
      link = create(:organization_link, siret: "21750056000016", insee_code: "75056")

      result = nil
      expect { result = register(build(:api_internal_agent_form)) }.not_to change(OrganizationLink, :count)

      expect(result.membership.organization_link).to eq(link)
    end

    it "registers a local administrator without habilitation" do
      result = register(build(:api_internal_agent_form, :local_administrator))

      expect(result.membership).to have_attributes(role: "local_administrator", data_stream_codes: [])
    end

    # Un appel simultané a rattaché l'agent depuis les vérifications.
    it "refuses as already attached an agent attached since the checks, writing nothing" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75056"))

      result = nil
      expect { result = register(build(:api_internal_agent_form, email: "alice.martin@ville.fr")) }
        .not_to change { [Membership.count, Event.count] }

      expect(result).to be_failure
      expect(result.refusals).to eq([:already_attached])
    end

    # Un appel simultané a rattaché l'agent à ce SIRET sous un autre code guichet.
    it "refuses as attached to the SIRET an agent attached since the checks under another insee code, writing nothing" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75101"))

      result = nil
      expect { result = register(build(:api_internal_agent_form, email: "alice.martin@ville.fr")) }
        .not_to change { [Membership.count, Event.count] }

      expect(result).to be_failure
      expect(result.refusals).to eq([:siret_already_attached])
    end

    it "lets any other refusal of the membership raise" do
      form = build(:api_internal_agent_form, job_title: "x" * 256)

      expect { described_class.call(form:, api_client:, request_id: "req-1") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "writes nothing when a trace cannot be written" do
      form = build(:api_internal_agent_form)
      expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { register(form) }.to raise_error(ActiveRecord::RecordInvalid)

      expect([Agent.count, OrganizationLink.count, Membership.count, DataStreamAccess.count, Event.count])
        .to eq([0, 0, 0, 0, 0])
    end
  end
end
