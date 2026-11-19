# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::MembershipUpdateForm do
  # Le cas standard : un membre habilité sur un flux.
  let(:membership) { attach(role: "member", codes: ["CERTDC"]) }

  def attach(role:, codes:)
    create(:membership, role:).tap do |membership|
      codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    end
  end

  def errors_of(form)
    form.validate
    form.errors.details
  end

  describe "#valid?" do
    it "accepts an update without any key" do
      expect(described_class.new(membership:)).to be_valid
    end

    it "accepts every field well formed" do
      form = described_class.new(
        membership:, role: "local_administrator", job_title: "Officier d'état civil",
        phone_number: "01 23 45 67 89", mobile_phone_number: "+33612345678", data_stream_codes: ["DECES"]
      )

      expect(form).to be_valid
    end

    it "accepts the erasure of the job title and the phones" do
      expect(described_class.new(membership:, job_title: nil, phone_number: nil, mobile_phone_number: "")).to be_valid
    end

    it "refuses a role that is blank" do
      expect(errors_of(described_class.new(membership:, role: nil))).to eq(role: [{error: :blank}])
    end

    it "refuses a role outside the closed list" do
      expect(errors_of(described_class.new(membership:, role: "x"))).to eq(role: [{error: :inclusion, value: "x"}])
    end

    # Une liste dont chaque élément est dans l'ensemble passerait un contrôle d'inclusion.
    it "refuses a role that is a list" do
      expect(errors_of(described_class.new(membership:, role: ["member"]))).to eq(role: [{error: :inclusion, value: '["member"]'}])
    end

    it "refuses a job title longer than 255 characters" do
      expect(errors_of(described_class.new(membership:, job_title: "a" * 256))).to eq(job_title: [{error: :too_long, count: 255}])
    end

    [["Officier d'état civil"], {"title" => "Officier"}, 5, true].each do |job_title|
      it "refuses a job title that is not text (#{job_title.inspect})" do
        expect(errors_of(described_class.new(membership:, job_title:))).to eq(job_title: [{error: :invalid}])
      end
    end

    it "refuses phones that are not E.164 once normalized" do
      expect(errors_of(described_class.new(membership:, phone_number: "123", mobile_phone_number: ["+33612345678"]))).to eq(
        phone_number: [{error: :invalid, value: "123"}],
        mobile_phone_number: [{error: :invalid, value: '["+33612345678"]'}]
      )
    end

    # Changer d'organisation, c'est retirer le rattachement puis en ajouter un : la demande n'est pas ignorée.
    it "refuses a siret or an insee code, whatever their value" do
      expect(errors_of(described_class.new(membership:, siret: membership.organization_link.siret, insee_code: nil)))
        .to eq(siret: [{error: :immutable}], insee_code: [{error: :immutable}])
    end

    it "has no reason on data_stream_codes when they are not received" do
      expect(errors_of(described_class.new(membership:, role: "member"))).to eq({})
    end

    it "refuses a null in the list, a null list and a string" do
      expect([
        errors_of(described_class.new(membership:, data_stream_codes: [nil])),
        errors_of(described_class.new(membership:, data_stream_codes: nil)),
        errors_of(described_class.new(membership:, data_stream_codes: "CERTDC"))
      ]).to all(eq(data_stream_codes: [{error: :not_a_list}]))
    end

    it "refuses more than 100 codes" do
      expect(errors_of(described_class.new(membership:, data_stream_codes: Array.new(101) { "FLUX-#{it}" })))
        .to eq(data_stream_codes: [{error: :too_many, count: 100}])
    end

    it "refuses a malformed code" do
      expect(errors_of(described_class.new(membership:, data_stream_codes: ["CERT DC"])))
        .to eq(data_stream_codes: [{error: :invalid_code, code: "CERT DC"}])
    end

    context "with the rule of at least one code for a member, on the resulting state" do
      it "refuses to empty the list of a member" do
        expect(errors_of(described_class.new(membership:, data_stream_codes: [])))
          .to eq(data_stream_codes: [{error: :required_for_member}])
      end

      it "refuses to turn a local administrator without code into a member" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(errors_of(described_class.new(membership: administrator, role: "member")))
          .to eq(data_stream_codes: [{error: :required_for_member}])
      end

      it "refuses to turn a local administrator into a member with an empty list" do
        administrator = attach(role: "local_administrator", codes: ["CERTDC"])

        expect(errors_of(described_class.new(membership: administrator, role: "member", data_stream_codes: [])))
          .to eq(data_stream_codes: [{error: :required_for_member}])
      end

      it "accepts to turn a local administrator without code into a member with a code" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(described_class.new(membership: administrator, role: "member", data_stream_codes: ["CERTDC"])).to be_valid
      end

      it "accepts to promote a member to local administrator with an empty list and the flag" do
        expect(described_class.new(membership:, role: "local_administrator", data_stream_codes: [], all_data_streams: true)).to be_valid
      end

      it "accepts to empty the list of a local administrator with the flag" do
        administrator = attach(role: "local_administrator", codes: ["CERTDC"])

        expect(described_class.new(membership: administrator, data_stream_codes: [], all_data_streams: true)).to be_valid
      end

      # Le motif de forme suffit : une liste mal formée n'est pas jugée vide.
      it "gives only the shape reason for a malformed list on a member" do
        expect(errors_of(described_class.new(membership:, data_stream_codes: nil)))
          .to eq(data_stream_codes: [{error: :not_a_list}])
      end

      # Un membre dont le rôle reçu est invalide n'a pas d'état résultant à juger.
      it "gives only the role reason for an invalid role" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(errors_of(described_class.new(membership: administrator, role: "x"))).to eq(role: [{error: :inclusion, value: "x"}])
      end
    end

    # Décocher le dernier flux d'un administrateur local lui ouvrirait tous les flux : l'état résultant
    # « administrateur local sans code » doit être confirmé, sauf s'il est déjà l'état actuel.
    context "with the confirmation of the access to every data stream" do
      it "refuses to empty the list of a local administrator without the flag" do
        administrator = attach(role: "local_administrator", codes: ["CERTDC"])

        expect(errors_of(described_class.new(membership: administrator, data_stream_codes: [])))
          .to eq(data_stream_codes: [{error: :grants_all_data_streams}])
      end

      it "refuses to promote a member to local administrator with an empty list without the flag" do
        expect(errors_of(described_class.new(membership:, role: "local_administrator", data_stream_codes: [])))
          .to eq(data_stream_codes: [{error: :grants_all_data_streams}])
      end

      # false vaut absence : il ne confirme rien.
      it "refuses to empty the list of a local administrator with the flag at false" do
        administrator = attach(role: "local_administrator", codes: ["CERTDC"])

        expect(errors_of(described_class.new(membership: administrator, data_stream_codes: [], all_data_streams: false)))
          .to eq(data_stream_codes: [{error: :grants_all_data_streams}])
      end

      it "accepts the flag at false where it is not needed" do
        expect(described_class.new(membership:, job_title: "Officier", all_data_streams: false)).to be_valid
      end

      it "accepts an update that keeps a local administrator without code, without the flag" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(described_class.new(membership: administrator, job_title: "Officier", data_stream_codes: [])).to be_valid
      end

      # Un rejeu de la demande confirmée ne doit pas échouer une fois l'état atteint.
      it "accepts the flag again on a local administrator already without code" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(described_class.new(membership: administrator, data_stream_codes: [], all_data_streams: true)).to be_valid
      end

      ["true", 1, nil, [true], {"value" => true}].each do |flag|
        it "refuses a flag that is not a JSON boolean (#{flag.inspect})" do
          administrator = attach(role: "local_administrator", codes: ["CERTDC"])

          expect(errors_of(described_class.new(membership: administrator, data_stream_codes: [], all_data_streams: flag)))
            .to eq(all_data_streams: [{error: :inclusion, value: flag}])
        end
      end

      it "refuses the flag on a resulting member" do
        expect(errors_of(described_class.new(membership:, data_stream_codes: ["DECES"], all_data_streams: true)))
          .to eq(all_data_streams: [{error: :requires_empty_list}])
      end

      it "refuses the flag on a local administrator who keeps codes" do
        administrator = attach(role: "local_administrator", codes: [])

        expect(errors_of(described_class.new(membership: administrator, data_stream_codes: ["CERTDC"], all_data_streams: true)))
          .to eq(all_data_streams: [{error: :requires_empty_list}])
      end

      # Les deux motifs : la liste vide d'un membre, et un drapeau qui ne s'y applique pas.
      it "refuses the flag with an empty list on a member" do
        expect(errors_of(described_class.new(membership:, data_stream_codes: [], all_data_streams: true)))
          .to eq(all_data_streams: [{error: :requires_empty_list}], data_stream_codes: [{error: :required_for_member}])
      end

      # Le motif de forme suffit : une liste mal formée n'est pas jugée vide.
      it "gives only the shape reason for a malformed list on a local administrator" do
        administrator = attach(role: "local_administrator", codes: ["CERTDC"])

        expect(errors_of(described_class.new(membership: administrator, data_stream_codes: nil, all_data_streams: true)))
          .to eq(data_stream_codes: [{error: :not_a_list}])
      end
    end
  end

  describe "#data_stream_codes_to_verify" do
    it "gives the received codes the membership does not already hold" do
      form = described_class.new(membership:, data_stream_codes: ["CERTDC", "NOUVEAU"])

      expect(form.data_stream_codes_to_verify).to eq(["NOUVEAU"])
    end

    it "is empty when the codes are not received" do
      expect(described_class.new(membership:, role: "local_administrator").data_stream_codes_to_verify).to eq([])
    end
  end

  describe "#changes" do
    it "is empty when no key is received" do
      expect(described_class.new(membership:).changes).to eq({})
    end

    it "compares the codes as sets and gives them sorted" do
      form = described_class.new(membership:, data_stream_codes: ["NOUVEAU", "CERTDC"])

      expect(form.changes).to eq(data_stream_codes: [["CERTDC"], ["CERTDC", "NOUVEAU"]])
    end

    it "sees no change for the same codes in another order, with a duplicate" do
      habilitated = attach(role: "member", codes: ["DECES", "CERTDC"])

      expect(described_class.new(membership: habilitated, data_stream_codes: ["CERTDC", "DECES", "CERTDC"]).changes).to eq({})
    end

    # Le drapeau confirme la demande sans être un champ du rattachement : il n'est pas un changement.
    it "gives the before and after of each received field that differs, without the flag" do
      membership.update!(job_title: "Agent", phone_number: "+33123456789")
      form = described_class.new(
        membership:, role: "local_administrator", job_title: "Officier", phone_number: "01 23 45 67 89",
        mobile_phone_number: "06 12 34 56 78", data_stream_codes: [], all_data_streams: true
      )

      expect(form.changes).to eq(
        role: ["member", "local_administrator"],
        job_title: ["Agent", "Officier"],
        mobile_phone_number: [nil, "+33612345678"],
        data_stream_codes: [["CERTDC"], []]
      )
    end

    it "sees no change for a blank job title on a membership without one" do
      expect(described_class.new(membership:, job_title: "").changes).to eq({})
    end

    it "reads a blank job title as an erasure" do
      membership.update!(job_title: "Agent")

      expect(described_class.new(membership:, job_title: "").changes).to eq(job_title: ["Agent", nil])
    end

    it "reads a null as an erasure" do
      membership.update!(job_title: "Agent", mobile_phone_number: "+33612345678")

      expect(described_class.new(membership:, job_title: nil, mobile_phone_number: nil).changes)
        .to eq(job_title: ["Agent", nil], mobile_phone_number: ["+33612345678", nil])
    end
  end

  describe "#valid_on?" do
    it "is true for a field without reason and false for one with" do
      form = described_class.new(membership:, role: "x")
      form.validate

      expect(form.valid_on?(:data_stream_codes)).to be(true)
      expect(form.valid_on?(:role)).to be(false)
    end
  end

  describe "#error_details" do
    it "gives the reasons by field" do
      form = described_class.new(membership:, role: "", data_stream_codes: [nil])
      form.validate

      expect(form.error_details).to eq(role: ["doit être rempli(e)"], data_stream_codes: ["doit être une liste de codes"])
    end

    it "words the rule of at least one code for a member" do
      form = described_class.new(membership:, data_stream_codes: [])
      form.validate

      expect(form.error_details).to eq(data_stream_codes: ["doit compter au moins un code pour un membre"])
    end

    it "words the confirmation of the access to every data stream and the misuse of the flag" do
      administrator = attach(role: "local_administrator", codes: ["CERTDC"])
      unconfirmed = described_class.new(membership: administrator, data_stream_codes: []).tap(&:validate)
      misused = described_class.new(membership:, all_data_streams: true).tap(&:validate)
      malformed = described_class.new(membership:, all_data_streams: "true").tap(&:validate)

      expect(unconfirmed.error_details).to eq(
        data_stream_codes: ["donnerait accès à tous les flux de l'organisation : envoyez all_data_streams à true pour le confirmer"]
      )
      expect(misused.error_details).to eq(all_data_streams: ["ne s'emploie qu'avec une liste vide pour un administrateur local"])
      expect(malformed.error_details).to eq(all_data_streams: ["doit être le booléen JSON true ou false"])
    end

    it "words the refusal of the organization" do
      form = described_class.new(membership:, siret: "13002526500013").tap(&:validate)

      expect(form.error_details).to eq(siret: ["ne se modifie pas : retirez le rattachement puis ajoutez-en un par POST /agents"])
    end
  end
end
