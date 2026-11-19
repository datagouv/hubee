# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PATCH /api/internal/v1/agents/:agent_id/memberships/:id", type: :request do
  def modify(body, agent_id: agent.id, membership_id: membership.id, application: admin_portal, actor: declared_actor)
    patch "/api/internal/v1/agents/#{agent_id}/memberships/#{membership_id}", params: body, headers: {**bearer(application), **actor}, as: :json
  end

  # Le cas standard : un membre habilité sur un flux.
  def attach(agent, siret: "21750056000016", insee_code: "75056", codes: ["CERTDC"])
    membership = create(:membership, agent:, organization_link: create(:organization_link, siret:, insee_code:))
    codes.each { create(:data_stream_access, membership:, data_stream_code: it) }
    membership
  end

  # Tout ce qu'un refus ne doit pas écrire.
  def written
    membership.reload
    [membership.attributes, membership.data_stream_codes.sort, Event.count]
  end

  let(:admin_portal) { create(:oauth_application, :admin_portal, name: "admin-portal") }
  let!(:agent) { create(:agent, email: "alice.martin@ville.fr") }
  let!(:membership) { attach(agent) }
  let(:json) { JSON.parse(response.body) }

  # La liste vide ouvre tous les flux : le drapeau confirme que c'est voulu, sans figurer dans la trace.
  it "promotes a member to local administrator with access to every data stream once confirmed" do
    modify({membership: {role: "local_administrator", data_stream_codes: [], all_data_streams: true}})

    expect(response).to have_http_status(:ok)
    expect(json).to eq(
      "id" => membership.id,
      "siret" => "21750056000016",
      "insee_code" => "75056",
      "role" => "local_administrator",
      "job_title" => nil,
      "phone_number" => nil,
      "mobile_phone_number" => nil,
      "data_stream_codes" => [],
      "last_signed_in_at" => nil
    )
    expect(membership.reload.data_stream_accesses).to be_empty
    expect(Event.sole).to have_attributes(
      event_type: "membership.updated",
      eventable: membership,
      metadata: {
        "api_client" => "admin-portal",
        "api_client_uid" => admin_portal.uid,
        "request_id" => response.headers["X-Request-Id"],
        "declared_actor" => "admin-national-42",
        "email" => "alice.martin@ville.fr",
        "siret" => "21750056000016",
        "insee_code" => "75056",
        "changes" => {
          "role" => ["member", "local_administrator"],
          "data_stream_codes" => [["CERTDC"], []]
        }
      }
    )
  end

  # Seul DECES, ajouté, est demandé au référentiel : CERTDC est gardé, AEC retiré.
  it "replaces the habilitations, verifying only the added codes" do
    create(:data_stream_access, membership:, data_stream_code: "AEC")
    client = use_hub_api_fake_client
    expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "DECES", client:)
      .and_return(build_v2_data_stream(code: "DECES"))

    modify({membership: {job_title: "Officier d'état civil", data_stream_codes: ["CERTDC", "DECES"]}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("job_title" => "Officier d'état civil", "data_stream_codes" => contain_exactly("CERTDC", "DECES"))
    expect(membership.data_stream_accesses.pluck(:data_stream_code)).to contain_exactly("CERTDC", "DECES")
    expect(Event.sole.metadata["changes"]).to eq(
      "job_title" => [nil, "Officier d'état civil"],
      "data_stream_codes" => [["AEC", "CERTDC"], ["CERTDC", "DECES"]]
    )
  end

  # CERTDC, déjà accordé, n'est pas revérifié : seul DECES est demandé au référentiel.
  it "accepts an envelope holding only data_stream_codes" do
    client = use_hub_api_fake_client
    expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "DECES", client:)
      .and_return(build_v2_data_stream(code: "DECES"))

    modify({membership: {data_stream_codes: ["CERTDC", "DECES"]}})

    expect(response).to have_http_status(:ok)
    expect(json["data_stream_codes"]).to contain_exactly("CERTDC", "DECES")
    expect(membership.data_stream_accesses.pluck(:data_stream_code)).to contain_exactly("CERTDC", "DECES")
  end

  it "corrects the job title and the phones, and erases them with a null" do
    membership.update!(job_title: "Agent", phone_number: "+33123456789")

    modify({membership: {job_title: nil, phone_number: nil, mobile_phone_number: "06 12 34 56 78"}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("job_title" => nil, "phone_number" => nil, "mobile_phone_number" => "+33612345678", "data_stream_codes" => ["CERTDC"])
    expect(Event.sole.metadata["changes"]).to eq(
      "job_title" => ["Agent", nil],
      "phone_number" => ["+33123456789", nil],
      "mobile_phone_number" => [nil, "+33612345678"]
    )
  end

  it "keeps the habilitations of a member promoted without data_stream_codes" do
    modify({membership: {role: "local_administrator"}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("role" => "local_administrator", "data_stream_codes" => ["CERTDC"])
  end

  it "refuses an unknown added code" do
    stub_hub_api_v2_data_stream_not_found(code: "INCONNU")

    expect { modify({membership: {role: "local_administrator", data_stream_codes: ["INCONNU"]}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["contient un code de flux inconnu du référentiel : « INCONNU »"])
  end

  it "answers 503 when hub-api does not answer" do
    stub_hub_api_v2_data_stream_error(code: "DECES")

    expect { modify({membership: {data_stream_codes: ["DECES"]}}) }.not_to change { written }

    expect(response).to have_http_status(:service_unavailable)
    expect(json).to eq("error" => "service_unavailable", "message" => "Le référentiel V1 ne répond pas. Réessayez dans quelques instants.")
  end

  # Ni [null] ni null ne doivent devenir une liste vide : elle donnerait tous les flux à un administrateur local.
  [[nil], nil, "CERTDC", [{"code" => "CERTDC"}]].each do |codes|
    it "refuses data_stream_codes that are not a list of strings (#{codes.inspect})" do
      expect { modify({membership: {role: "local_administrator", data_stream_codes: codes}}) }.not_to change { written }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("data_stream_codes" => ["doit être une liste de codes"])
    end
  end

  # Décocher le dernier flux d'un administrateur local lui ouvrirait tous les flux, sans que rien ne le confirme.
  it "refuses to empty the list of a local administrator without the flag" do
    membership.update!(role: "local_administrator")

    expect { modify({membership: {data_stream_codes: []}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["donnerait accès à tous les flux de l'organisation : envoyez all_data_streams à true pour le confirmer"])
  end

  it "refuses to promote a member to local administrator with an empty list without the flag" do
    expect { modify({membership: {role: "local_administrator", data_stream_codes: [], all_data_streams: false}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["donnerait accès à tous les flux de l'organisation : envoyez all_data_streams à true pour le confirmer"])
  end

  it "empties the list of a local administrator with the flag, and traces the list before and after" do
    membership.update!(role: "local_administrator")

    modify({membership: {data_stream_codes: [], all_data_streams: true}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("role" => "local_administrator", "data_stream_codes" => [])
    expect(membership.data_stream_accesses).to be_empty
    expect(Event.sole.metadata["changes"]).to eq("data_stream_codes" => [["CERTDC"], []])
  end

  # Le rejeu d'une demande confirmée trouve l'état déjà atteint : il répond sans erreur ni écriture.
  it "replays a confirmed request without error nor write" do
    membership.update!(role: "local_administrator")
    DataStreamAccess.where(membership:).delete_all

    expect { modify({membership: {data_stream_codes: [], all_data_streams: true}}) }.not_to change { written }

    expect(response).to have_http_status(:ok)
    expect(json).to include("role" => "local_administrator", "data_stream_codes" => [])
  end

  ["true", 1, nil, [true]].each do |flag|
    it "refuses a flag that is not a JSON boolean (#{flag.inspect})" do
      membership.update!(role: "local_administrator")

      expect { modify({membership: {data_stream_codes: [], all_data_streams: flag}}) }.not_to change { written }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("all_data_streams" => ["doit être le booléen JSON true ou false"])
    end
  end

  it "refuses the flag on a member" do
    expect { modify({membership: {job_title: "Officier", all_data_streams: true}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("all_data_streams" => ["ne s'emploie qu'avec une liste vide pour un administrateur local"])
  end

  it "refuses the flag with a list that is not empty" do
    membership.update!(role: "local_administrator")

    expect { modify({membership: {data_stream_codes: ["CERTDC"], all_data_streams: true}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("all_data_streams" => ["ne s'emploie qu'avec une liste vide pour un administrateur local"])
  end

  it "refuses to empty the habilitations of a member" do
    expect { modify({membership: {data_stream_codes: []}}) }.not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["doit compter au moins un code pour un membre"])
  end

  it "refuses to turn a local administrator with access to every data stream into a member without code" do
    administrator = attach(create(:agent), siret: "13002526500013", codes: [])
    administrator.update!(role: "local_administrator")

    modify({membership: {role: "member"}}, agent_id: administrator.agent_id, membership_id: administrator.id)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["doit compter au moins un code pour un membre"])
    expect(administrator.reload.role).to eq("local_administrator")
  end

  # Un autre appel rétrograde l'administrateur local entre les vérifications et l'écriture : la liste vide,
  # valide contre l'état lu au début, ferait un membre sans habilitation.
  it "refuses with its reason a request that a concurrent change makes invalid" do
    membership.update!(role: "local_administrator")
    expect(API::Internal::V1::Agents::Shared::EnsureNoRefusal).to receive(:call!).and_wrap_original do |original, context|
      original.call(context)
      Membership.find(membership.id).update!(role: "member")
    end

    modify({membership: {data_stream_codes: [], all_data_streams: true}})

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq(
      "all_data_streams" => ["ne s'emploie qu'avec une liste vide pour un administrateur local"],
      "data_stream_codes" => ["doit compter au moins un code pour un membre"]
    )
    expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
    expect(Event.count).to eq(0)
  end

  # Sans code au début, l'administrateur local n'avait rien à confirmer ; un autre appel lui accorde un code
  # entre les vérifications et l'écriture : la liste vide lui ouvrirait alors tous les flux sans confirmation.
  it "refuses an unconfirmed empty list once a concurrent call has granted a code" do
    membership.update!(role: "local_administrator")
    DataStreamAccess.where(membership:).delete_all
    expect(API::Internal::V1::Agents::Shared::EnsureNoRefusal).to receive(:call!).and_wrap_original do |original, context|
      original.call(context)
      create(:data_stream_access, membership: Membership.find(membership.id), data_stream_code: "CERTDC")
    end

    modify({membership: {data_stream_codes: []}})

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq("data_stream_codes" => ["donnerait accès à tous les flux de l'organisation : envoyez all_data_streams à true pour le confirmer"])
    expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
    expect(Event.count).to eq(0)
  end

  it "refuses every invalid field together" do
    expect { modify({membership: {role: "", job_title: "a" * 256, phone_number: "123", data_stream_codes: ["CERT DC"]}}) }
      .not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq(
      "role" => ["doit être rempli(e)"],
      "job_title" => ["est trop long (pas plus de 255 caractères)"],
      "phone_number" => ["n'est pas valide"],
      "data_stream_codes" => ["contient un code invalide : « CERT DC »"]
    )
  end

  [["role", ["local_administrator"]], ["job_title", ["Officier"]], ["phone_number", {"number" => "+33123456789"}], ["mobile_phone_number", true]].each do |field, value|
    it "refuses a non-scalar #{field} instead of dropping it (#{value.inspect})" do
      expect { modify({membership: {field => value}}) }.not_to change { written }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.keys).to eq([field])
    end
  end

  it "writes nothing for an unchanged membership" do
    expect { modify({membership: {role: "member", phone_number: nil, data_stream_codes: ["CERTDC"]}}) }.not_to change { written }

    expect(response).to have_http_status(:ok)
    expect(json).to include("id" => membership.id, "role" => "member", "data_stream_codes" => ["CERTDC"])
  end

  # Un formulaire HTML envoie « » pour un champ laissé vide : sans fonction à effacer, rien ne change.
  it "writes nothing for a blank job title on a membership without one" do
    expect { modify({membership: {job_title: ""}}) }.not_to change { written }

    expect(response).to have_http_status(:ok)
    expect(json).to include("job_title" => nil)
  end

  it "erases the job title with a blank one" do
    membership.update!(job_title: "Agent")

    modify({membership: {job_title: ""}})

    expect(response).to have_http_status(:ok)
    expect(json).to include("job_title" => nil)
    expect(Event.sole.metadata["changes"]).to eq("job_title" => ["Agent", nil])
  end

  [{}, {first_name: "Alice"}].each do |envelope|
    it "answers the current state without writing for an envelope holding nothing to modify (#{envelope})" do
      expect { modify({membership: envelope}) }.not_to change { written }

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => membership.id, "siret" => "21750056000016", "role" => "member")
    end
  end

  # Ignorée, la demande de changer d'organisation passerait pour faite.
  it "refuses a siret and an insee code instead of ignoring them" do
    expect { modify({membership: {role: "local_administrator", siret: "13002526500013", insee_code: "75056"}}) }
      .not_to change { written }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq(
      "siret" => ["ne se modifie pas : retirez le rattachement puis ajoutez-en un par POST /agents"],
      "insee_code" => ["ne se modifie pas : retirez le rattachement puis ajoutez-en un par POST /agents"]
    )
  end

  it "answers 404 for the membership of another agent" do
    other = attach(create(:agent), siret: "13002526500013")

    expect { modify({membership: {role: "local_administrator"}}, membership_id: other.id) }
      .not_to change { [other.reload.attributes, Event.count] }

    expect(response).to have_http_status(:not_found)
    expect(json).to eq("error" => "not_found", "message" => "Ressource introuvable.")
  end

  [SecureRandom.uuid, "pas-un-uuid"].each do |id|
    it "answers 404 for an unknown agent or membership (#{id})" do
      expect { modify({membership: {role: "local_administrator"}}, agent_id: id) }.not_to change { written }
      expect(response).to have_http_status(:not_found)

      expect { modify({membership: {role: "local_administrator"}}, membership_id: id) }.not_to change { written }
      expect(response).to have_http_status(:not_found)
    end
  end

  [nil, "member", ["member"]].each do |envelope|
    it "refuses a membership that is not an object (#{envelope.inspect})" do
      expect { modify({membership: envelope}) }.not_to change { written }

      expect(response).to have_http_status(:bad_request)
      expect(json).to include("error" => "missing_membership")
    end
  end

  it "refuses a request without the membership envelope" do
    expect { modify({role: "local_administrator"}) }.not_to change { written }

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq("error" => "missing_membership", "message" => "La demande doit porter le rattachement sous la clé « membership ».")
  end

  it "refuses a client holding only internal:agents:read, even on an unknown membership" do
    reader = create(:oauth_application, :with_agent_read_right)

    modify({membership: {role: "local_administrator"}}, agent_id: SecureRandom.uuid, membership_id: SecureRandom.uuid, application: reader)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:read without writing" do
    reader = create(:oauth_application, :with_agent_read_right)

    expect { modify({membership: {role: "local_administrator", data_stream_codes: [], all_data_streams: true}}, application: reader) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  # hub-api n'a que le droit d'enregistrer : il ne modifie pas un rattachement.
  it "refuses a client holding only internal:agents:create, even on an unknown membership" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    modify({membership: {role: "local_administrator"}}, agent_id: SecureRandom.uuid, membership_id: SecureRandom.uuid, application: registrar)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "refuses a client holding only internal:agents:create without writing" do
    registrar = create(:oauth_application, :with_agent_registration_right)

    expect { modify({membership: {role: "local_administrator", data_stream_codes: [], all_data_streams: true}}, application: registrar) }.not_to change { written }

    expect(response).to have_http_status(:forbidden)
  end

  it_behaves_like "a write requiring the declared actor" do
    def write_as(actor) = modify({membership: {job_title: "Officier d'état civil"}}, actor:)
  end

  it "answers 403 to a client without the right before asking for the declared actor" do
    reader = create(:oauth_application, :with_agent_read_right)

    modify({membership: {job_title: "Officier d'état civil"}}, application: reader, actor: {})

    expect(response).to have_http_status(:forbidden)
  end

  it "asks for the declared actor before looking for the membership" do
    modify({membership: {job_title: "Officier d'état civil"}}, membership_id: SecureRandom.uuid, actor: {})

    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error" => "missing_actor")
  end

  # L'autorisation passe avant l'en-tête d'acteur, qui passe avant la lecture du corps, qui passe avant la
  # recherche du rattachement.
  context "with an unreadable body", :production_exceptions do
    def modify_unreadable(application, actor: declared_actor)
      patch "/api/internal/v1/agents/#{SecureRandom.uuid}/memberships/#{SecureRandom.uuid}",
        params: "{pas du json", headers: {"CONTENT_TYPE" => "application/json", **bearer(application), **actor}
    end

    it "asks for the declared actor before reading the body" do
      modify_unreadable(admin_portal, actor: {})

      expect(response).to have_http_status(:bad_request)
      expect(json).to include("error" => "missing_actor")
    end

    it "answers 403 to a client without the right, even on an unknown membership" do
      modify_unreadable(create(:oauth_application))

      expect(response).to have_http_status(:forbidden)
      expect(json).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
    end

    it "answers 400 to a client with the right, before looking for the unknown membership" do
      modify_unreadable(admin_portal)

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => "bad_request", "message" => "La requête est mal formée.")
    end
  end

  it "refuses without a token" do
    patch "/api/internal/v1/agents/#{agent.id}/memberships/#{membership.id}", params: {membership: {role: "local_administrator"}}, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
  end
end
