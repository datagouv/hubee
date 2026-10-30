# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::AgentForm do
  # Le cas standard : un membre habilité sur un flux.
  def payload(identity = {}, membership = {})
    {
      email: "alice.martin@ville.fr",
      first_name: "Alice",
      last_name: "Martin",
      **identity,
      membership: {siret: "21750056000016", insee_code: "75056", role: "member", data_stream_codes: ["CERTDC"], **membership}
    }
  end

  def form(identity = {}, membership = {}) = described_class.new(**payload(identity, membership))

  def errors_of(form)
    form.validate
    form.errors.details
  end

  describe "#valid?" do
    it "accepts a member habilitated on a data stream" do
      expect(form).to be_valid
    end

    it "accepts the optional fields" do
      complete = form(
        {civility: "ms"},
        {job_title: "Officier d'état civil", phone_number: "+33123456789", mobile_phone_number: "+33612345678"}
      )

      expect(complete).to be_valid
    end

    it "requires the identity and the attachment of the agent" do
      empty = described_class.new

      expect(errors_of(empty)).to include(
        email: [{error: :blank}],
        first_name: [{error: :blank}],
        last_name: [{error: :blank}],
        siret: [{error: :blank}],
        insee_code: [{error: :blank}],
        role: [{error: :blank}],
        data_stream_codes: [{error: :missing}]
      )
    end

    it "refuses a malformed address" do
      expect(errors_of(form(email: "alice.martin"))).to eq(email: [{error: :invalid, value: "alice.martin"}])
    end

    it "refuses a SIRET that is not 14 digits" do
      expect(errors_of(form({}, siret: "2175005600001"))).to eq(siret: [{error: :invalid, value: "2175005600001"}])
    end

    it "takes a blank civility for an absent one" do
      blank = form(civility: "")

      expect(blank).to be_valid
      expect(blank.civility).to be_nil
    end

    it "refuses a civility out of the closed list" do
      expect(errors_of(form(civility: "dr"))).to eq(civility: [{error: :inclusion, value: "dr"}])
    end

    # La base donne « member » par défaut, un rôle oublié ne doit jamais en devenir un.
    it "never defaults a missing role" do
      expect(errors_of(form({}, role: nil))).to eq(role: [{error: :blank}])
    end

    it "refuses a role other than member and local administrator" do
      expect(errors_of(form({}, role: "admin"))).to eq(role: [{error: :inclusion, value: "admin"}])
    end

    it "refuses a phone number that cannot be put in E.164 form" do
      expect(errors_of(form({}, phone_number: "01 23", mobile_phone_number: "abc"))).to eq(
        phone_number: [{error: :invalid, value: "0123"}],
        mobile_phone_number: [{error: :invalid, value: "abc"}]
      )
    end

    it "refuses a job title longer than the column" do
      expect(errors_of(form({}, job_title: "a" * 256))).to eq(job_title: [{error: :too_long, count: 255}])
    end

    # Un membre sans habilitation n'aurait accès à rien.
    it "refuses a member without any data stream code" do
      expect(errors_of(form({}, data_stream_codes: []))).to eq(data_stream_codes: [{error: :required_for_member}])
    end

    # Un administrateur local sans habilitation a accès à tous les flux de son organisation.
    it "accepts a local administrator without any data stream code" do
      expect(form({}, role: "local_administrator", data_stream_codes: [])).to be_valid
    end

    it "refuses absent data stream codes, even for a local administrator" do
      absent = described_class.new(**payload({}, role: "local_administrator").tap { it[:membership].delete(:data_stream_codes) })

      expect(errors_of(absent)).to eq(data_stream_codes: [{error: :missing}])
    end

    it "accepts a data stream code made of any character but a space, accents included" do
      expect(form({}, data_stream_codes: ["EtatCivil", "recensement_citoyen-2", "état-civil", "A/B", "50%"])).to be_valid
    end

    it "refuses a data stream code holding a Unicode space" do
      expect(errors_of(form({}, data_stream_codes: ["CERTDC", "CERT\u00A0DC", "CERT\u2009DC"]))).to eq(
        data_stream_codes: [
          {error: :invalid_code, code: "CERT\u00A0DC"},
          {error: :invalid_code, code: "CERT\u2009DC"}
        ]
      )
    end

    it "refuses a data stream code that is blank, holds a space or exceeds 100 characters" do
      expect(errors_of(form({}, data_stream_codes: ["CERTDC", "", "CERT DC", "A" * 101]))).to eq(
        data_stream_codes: [
          {error: :invalid_code, code: ""},
          {error: :invalid_code, code: "CERT DC"},
          {error: :invalid_code, code: "A" * 101}
        ]
      )
    end

    # Sans quoi un administrateur local recevrait tous les flux pour un seul code mal transmis.
    it "refuses data stream codes that are not a list of strings, with this sole reason" do
      expect([
        errors_of(form({}, role: "local_administrator", data_stream_codes: "CERTDC")),
        errors_of(form({}, role: "local_administrator", data_stream_codes: nil)),
        errors_of(form({}, data_stream_codes: "CERTDC")),
        errors_of(form({}, data_stream_codes: [{"code" => "CERTDC"}])),
        errors_of(form({}, data_stream_codes: ["CERTDC", nil]))
      ]).to all(eq(data_stream_codes: [{error: :not_a_list}]))
    end

    it "accepts 100 distinct data stream codes" do
      expect(form({}, data_stream_codes: Array.new(100) { "FLUX-#{it}" })).to be_valid
    end

    it "refuses more than 100 distinct data stream codes" do
      expect(errors_of(form({}, data_stream_codes: Array.new(101) { "FLUX-#{it}" })))
        .to eq(data_stream_codes: [{error: :too_many, count: 100}])
    end

    it "does not examine the codes one by one beyond the bound" do
      expect(errors_of(form({}, data_stream_codes: Array.new(101) { "FLUX #{it}" })))
        .to eq(data_stream_codes: [{error: :too_many, count: 100}])
    end

    it "counts a repeated code once against the bound" do
      expect(form({}, data_stream_codes: Array.new(100) { "FLUX-#{it}" } + ["FLUX-0"])).to be_valid
    end
  end

  describe "#email" do
    it "is normalized as the agent's address is" do
      expect(form(email: " Alice.Martin@Ville.FR ").email).to eq("alice.martin@ville.fr")
    end
  end

  describe "#phone_number" do
    it "is normalized as the membership's numbers are" do
      expect(form({}, phone_number: "01 23 45 67 89", mobile_phone_number: "06.12.34.56.78"))
        .to have_attributes(phone_number: "+33123456789", mobile_phone_number: "+33612345678")
    end
  end

  # Un code est un identifiant opaque, dont la casse n'est jamais changée.
  describe "#data_stream_codes" do
    it "drops exact duplicates and keeps codes that only differ by case" do
      expect(form({}, data_stream_codes: ["CERTDC", "CERTDC", "certdc"]).data_stream_codes)
        .to eq(["CERTDC", "certdc"])
    end

    it "is stripped as an habilitation is, before duplicates are dropped" do
      expect(form({}, data_stream_codes: [" CERTDC", "CERTDC "]).data_stream_codes).to eq(["CERTDC"])
    end
  end

  describe "#valid_on?" do
    it "tells whether the given fields passed the validation" do
      invalid = form({}, siret: "123")
      invalid.validate

      expect(invalid.valid_on?(:email, :insee_code)).to be(true)
      expect(invalid.valid_on?(:email, :siret)).to be(false)
    end
  end

  # La forme du payload, enveloppe `agent` en moins.
  describe "#error_details" do
    it "nests the reasons on the membership under it, in French" do
      invalid = form({email: ""}, siret: "123", data_stream_codes: [])
      invalid.validate

      expect(invalid.error_details).to eq(
        email: ["doit être rempli(e)"],
        membership: {
          siret: ["doit comporter 14 chiffres"],
          data_stream_codes: ["doit compter au moins un code pour un membre"]
        }
      )
    end

    it "leaves the membership out when none of its fields is refused" do
      invalid = form(first_name: "")
      invalid.validate

      expect(invalid.error_details).to eq(first_name: ["doit être rempli(e)"])
    end
  end
end
