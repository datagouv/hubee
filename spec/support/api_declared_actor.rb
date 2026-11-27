# frozen_string_literal: true

# L'admin national qui agit, tel que le client le déclare dans X-Actor-Id : toute écriture de l'espace
# interne autre que l'enregistrement l'exige.
module APIDeclaredActorHelper
  DECLARED_ACTOR = "admin-national-42"

  def declared_actor(id = DECLARED_ACTOR) = {"X-Actor-Id" => id}
end

RSpec.configure do |config|
  config.include APIDeclaredActorHelper, type: :request
end

# L'écriture se fait par `write_as(actor_headers)`, que le groupe définit ; `written` rassemble ce
# qu'un refus ne doit pas écrire, traces comprises.
RSpec.shared_examples "a write requiring the declared actor" do
  {
    "without X-Actor-Id" => {},
    "with an empty X-Actor-Id" => {"X-Actor-Id" => ""},
    "with a blank X-Actor-Id" => {"X-Actor-Id" => "   "}
  }.each do |case_name, headers|
    it "answers 400 missing_actor #{case_name}, and writes nothing" do
      expect { write_as(headers) }.not_to change { written }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq(
        "error" => "missing_actor",
        "message" => "La demande doit désigner dans l'en-tête X-Actor-Id la personne qui agit."
      )
    end
  end

  {
    "a space" => "admin national",
    "an accent" => "élodie",
    "256 characters" => "a" * 256
  }.each do |case_name, id|
    it "answers 400 invalid_actor for an X-Actor-Id with #{case_name}, and writes nothing" do
      expect { write_as(declared_actor(id)) }.not_to change { written }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq(
        "error" => "invalid_actor",
        "message" => "L'en-tête X-Actor-Id doit compter de 1 à 255 caractères parmi les lettres ASCII sans accent, les chiffres et . _ : @ -."
      )
    end
  end

  it "traces the declared actor as sent" do
    write_as(declared_actor("portail-admin:agent.42_x@ac-me"))

    expect(response).to have_http_status(:success)
    expect(Event.sole.metadata).to include("declared_actor" => "portail-admin:agent.42_x@ac-me")
  end

  it "accepts 255 characters" do
    write_as(declared_actor("a" * 255))

    expect(response).to have_http_status(:success)
    expect(Event.sole.metadata["declared_actor"]).to eq("a" * 255)
  end
end
