# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Memberships::Update::Save do
  let(:api_client) { create(:oauth_application, name: "systeme-interne") }
  let(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  # Le cas standard : un membre habilité sur un flux.
  let!(:membership) do
    create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75056")).tap do
      create(:data_stream_access, membership: it, data_stream_code: "CERTDC")
    end
  end

  describe ".call" do
    def save(**attributes)
      form = API::Internal::V1::MembershipUpdateForm.new(membership:, **attributes).tap(&:validate)
      described_class.call(form:, api_client:, request_id: "req-1")
    end

    it "replaces the habilitations, writes the fields and the full trace in one transaction" do
      result = save(role: "local_administrator", job_title: "Officier", data_stream_codes: ["DECES", "AEC"])

      expect(result).to be_success
      expect(result.changed).to be(true)
      expect(membership.reload).to have_attributes(role: "local_administrator", job_title: "Officier")
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to contain_exactly("DECES", "AEC")
      expect(Event.sole).to have_attributes(
        event_type: "membership.updated",
        eventable: membership,
        metadata: {
          "api_client" => "systeme-interne",
          "api_client_uid" => api_client.uid,
          "request_id" => "req-1",
          "email" => "alice.martin@ville.fr",
          "siret" => "21750056000016",
          "insee_code" => "75056",
          "changes" => {
            "role" => ["member", "local_administrator"],
            "job_title" => [nil, "Officier"],
            "data_stream_codes" => [["CERTDC"], ["AEC", "DECES"]]
          }
        }
      )
    end

    # Le controller a lu le rattachement ; un autre appel le modifie avant le verrou. L'avant, l'écart écrit
    # et la trace sont ceux de l'état verrouillé.
    it "computes the changes from the state read under the lock, not the one loaded before" do
      loaded = Membership.includes(:data_stream_accesses).find(membership.id)
      loaded.data_stream_codes
      membership.update!(job_title: "Agent")
      create(:data_stream_access, membership:, data_stream_code: "DECES")
      form = API::Internal::V1::MembershipUpdateForm.new(membership: loaded, job_title: "Officier", data_stream_codes: ["DECES"]).tap(&:validate)

      described_class.call(form:, api_client:, request_id: "req-1")

      expect(membership.reload.job_title).to eq("Officier")
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["DECES"])
      expect(Event.sole.metadata["changes"]).to eq(
        "job_title" => ["Agent", "Officier"],
        "data_stream_codes" => [["CERTDC", "DECES"], ["DECES"]]
      )
    end

    # Valide contre l'administrateur local lu au début, la liste vide ferait du membre rétrogradé entre-temps
    # un membre sans habilitation.
    it "refuses, writing nothing, a request that the state read under the lock makes invalid" do
      membership.update!(role: "local_administrator")
      loaded = Membership.includes(:data_stream_accesses).find(membership.id)
      form = API::Internal::V1::MembershipUpdateForm.new(membership: loaded, data_stream_codes: [], all_data_streams: true).tap(&:validate)
      membership.update!(role: "member")

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_failure
      expect(form.errors.details).to eq(all_data_streams: [{error: :requires_empty_list}], data_stream_codes: [{error: :required_for_member}])
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
      expect(Event.count).to eq(0)
    end

    # Sans code au début, l'administrateur local n'avait rien à confirmer ; un code accordé entre-temps
    # fait de la liste vide un accès à tous les flux, que la demande n'a pas confirmé.
    it "refuses, writing nothing, an unconfirmed empty list once a concurrent call has granted a code" do
      membership.update!(role: "local_administrator")
      DataStreamAccess.where(membership:).delete_all
      loaded = Membership.includes(:data_stream_accesses).find(membership.id)
      form = API::Internal::V1::MembershipUpdateForm.new(membership: loaded, data_stream_codes: []).tap(&:validate)
      expect(form.errors).to be_empty
      create(:data_stream_access, membership:, data_stream_code: "CERTDC")

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_failure
      expect(form.errors.details).to eq(data_stream_codes: [{error: :grants_all_data_streams}])
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
      expect(Event.count).to eq(0)
    end

    it "writes nothing when a concurrent call has already made the change" do
      loaded = Membership.find(membership.id)
      membership.update!(job_title: "Officier")
      form = API::Internal::V1::MembershipUpdateForm.new(membership: loaded, job_title: "Officier").tap(&:validate)

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result.changed).to be(false)
      expect(Event.count).to eq(0)
    end

    it "keeps a habilitation that stays in the list" do
      kept = membership.data_stream_accesses.sole

      save(data_stream_codes: ["CERTDC", "DECES"])

      expect(membership.data_stream_accesses.pluck(:id, :data_stream_code)).to contain_exactly(
        [kept.id, "CERTDC"], [an_instance_of(String), "DECES"]
      )
    end

    it "leaves the habilitations alone when only a field changes" do
      kept = membership.data_stream_accesses.sole

      save(phone_number: "01 23 45 67 89")

      expect(membership.reload.phone_number).to eq("+33123456789")
      expect(membership.data_stream_accesses.sole).to eq(kept)
      expect(Event.sole.metadata["changes"]).to eq("phone_number" => [nil, "+33123456789"])
    end

    it "writes nothing when nothing changes" do
      result = save(role: "member", data_stream_codes: ["CERTDC"])

      expect(result).to be_success
      expect(result.changed).to be(false)
      expect(Event.count).to eq(0)
    end

    it "writes nothing when the trace fails" do
      expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { save(role: "local_administrator", data_stream_codes: [], all_data_streams: true) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(membership.reload.role).to eq("member")
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
    end
  end
end
