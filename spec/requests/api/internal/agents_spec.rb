# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API::Internal::Agents", type: :request do
  # Le cas standard : un membre habilité sur un flux, pour une organisation du référentiel.
  def payload(identity = {}, membership = {})
    {
      agent: {
        email: "alice.martin@ville.fr",
        first_name: "Alice",
        last_name: "Martin",
        **identity,
        membership: {siret: "21750056000016", insee_code: "75056", role: "member", data_stream_codes: ["CERTDC"], **membership}
      }
    }
  end

  def bearer(application)
    {"Authorization" => "Bearer #{create(:oauth_access_token, application:).plaintext_token}"}
  end

  def register(body, application: internal_client)
    post "/api/internal/agents", params: body, headers: bearer(application), as: :json
  end

  # Tout ce qu'un refus ne doit pas écrire.
  def written
    [Agent.count, OrganizationLink.count, Membership.count, DataStreamAccess.count, Event.count]
  end

  def attach(email:, siret: "21750056000016", insee_code: "75056", role: "member")
    agent = create(:agent, email:)
    create(:membership, agent:, role:, organization_link: create(:organization_link, siret:, insee_code:))
  end

  let(:internal_client) { create(:oauth_application, :with_agent_registration_right, name: "systeme-interne") }
  let(:json) { JSON.parse(response.body) }

  describe "POST /api/internal/agents" do
    context "with a new agent" do
      it "registers a member habilitated on a data stream and answers the registered state" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        register(payload(
          {civility: "ms"},
          {job_title: "Officier d'état civil", phone_number: "01 23 45 67 89", mobile_phone_number: "+33612345678"}
        ))

        expect(response).to have_http_status(:created)
        agent = Agent.sole
        expect(json).to eq(
          "id" => agent.id,
          "email" => "alice.martin@ville.fr",
          "first_name" => "Alice",
          "last_name" => "Martin",
          "civility" => "ms",
          "membership" => {
            "siret" => "21750056000016",
            "insee_code" => "75056",
            "role" => "member",
            "job_title" => "Officier d'état civil",
            "phone_number" => "+33123456789",
            "mobile_phone_number" => "+33612345678",
            "data_stream_codes" => ["CERTDC"]
          }
        )
        expect(agent.provider_sub).to be_nil
        expect(OrganizationLink.sole).to have_attributes(siret: "21750056000016", insee_code: "75056")
      end

      it "traces who granted what, without name nor phone" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        register(payload({}, phone_number: "+33123456789"))

        expect(response).to have_http_status(:created)
        granted = {
          "api_client" => "systeme-interne",
          "api_client_uid" => internal_client.uid,
          "request_id" => response.headers["X-Request-Id"],
          "email" => "alice.martin@ville.fr",
          "siret" => "21750056000016",
          "insee_code" => "75056",
          "role" => "member",
          "data_stream_codes" => ["CERTDC"]
        }
        expect(Event.order(:created_at).pluck(:event_type, :metadata))
          .to eq([["agent.created", granted], ["membership.created", granted]])
      end

      it "registers a local administrator habilitated on a data stream, bounded to it" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        register(payload({}, role: "local_administrator", data_stream_codes: ["CERTDC"]))

        expect(response).to have_http_status(:created)
        expect(json["membership"]).to include("role" => "local_administrator", "data_stream_codes" => ["CERTDC"])
        expect(Membership.sole).to have_attributes(role: "local_administrator", data_stream_codes: ["CERTDC"])
      end

      # Le cas de hub-api : l'administrateur local déclaré à l'abonnement a accès à tous les flux.
      it "registers a local administrator without habilitation" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

        hub_api = create(:oauth_application, :with_agent_registration_right, name: "hub-api")
        register(payload({}, role: "local_administrator", data_stream_codes: []), application: hub_api)

        expect(response).to have_http_status(:created)
        expect(json["membership"]).to include("role" => "local_administrator", "data_stream_codes" => [])
        expect(Membership.sole).to have_attributes(role: "local_administrator", data_stream_codes: [])
      end

      it "registers several local administrators for one organisation" do
        attach(email: "premier.admin@ville.fr", role: "local_administrator")
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

        register(payload({}, role: "local_administrator", data_stream_codes: []))

        expect(response).to have_http_status(:created)
        expect(Membership.where(role: "local_administrator").count).to eq(2)
        expect(OrganizationLink.count).to eq(1)
      end

      it "logs the request without the agent's identity nor phones" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        events = capture_semantic_logger_events do
          register(payload({civility: "ms"}, job_title: "Officier d'état civil", phone_number: "+33123456789", mobile_phone_number: "+33612345678"))
        end

        expect(events).to include(be_a_semantic_logger_event(message: "Completed #create", payload_includes: {
          params: {"agent" => {
            "email" => "[FILTERED]",
            "first_name" => "[FILTERED]",
            "last_name" => "[FILTERED]",
            "civility" => "[FILTERED]",
            "membership" => {
              "siret" => "21750056000016",
              "insee_code" => "75056",
              "role" => "member",
              "data_stream_codes" => ["CERTDC"],
              "job_title" => "[FILTERED]",
              "phone_number" => "[FILTERED]",
              "mobile_phone_number" => "[FILTERED]"
            }
          }}
        }))
      end

      # Un code est un identifiant opaque, que la V2 ne change jamais de casse.
      it "counts a repeated data stream code once and keeps codes that only differ by case" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")
        stub_hub_api_v2_data_stream(code: "certdc")

        register(payload({}, data_stream_codes: ["CERTDC", "CERTDC", "certdc"]))

        expect(response).to have_http_status(:created)
        expect(json["membership"]["data_stream_codes"]).to contain_exactly("CERTDC", "certdc")
        expect(DataStreamAccess.pluck(:data_stream_code)).to contain_exactly("CERTDC", "certdc")
      end
    end

    # Son identité est celle d'avant l'appel ; ProConnect la rafraîchit à la connexion.
    context "with an agent known for another SIRET" do
      it "attaches him without duplicate and answers his retained identity" do
        agent = create(:agent, email: "alice.martin@ville.fr", first_name: "Alicia", last_name: "Martin-Durand")
        create(:membership, agent:, organization_link: create(:organization_link, siret: "13002526500013"))
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        register(payload(email: "Alice.Martin@Ville.fr"))

        expect(response).to have_http_status(:created)
        expect(json).to include("id" => agent.id, "first_name" => "Alicia", "last_name" => "Martin-Durand")
        expect(Agent.count).to eq(1)
        expect(agent.reload.memberships.count).to eq(2)
        expect(Event.pluck(:event_type)).to eq(["membership.created"])
      end
    end

    # Tout rejeu est refusé : la V2 dit la vérité, chaque appelant traite ce refus à sa façon.
    context "with an agent already attached to this organisation" do
      before { stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056") }

      it "refuses an identical replay on the address, writes nothing and answers no state" do
        attach(email: "alice.martin@ville.fr")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq("email" => ["désigne un agent déjà rattaché à cette organisation"])
      end

      it "refuses a replay with another role and other habilitations, and changes nothing" do
        membership = attach(email: "alice.martin@ville.fr")
        stub_hub_api_v2_data_stream(code: "AEC")

        expect { register(payload({}, role: "local_administrator", data_stream_codes: ["AEC"])) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq("email" => ["désigne un agent déjà rattaché à cette organisation"])
        expect(membership.reload).to have_attributes(role: "member", data_stream_codes: [])
      end

      it "recognizes the agent whatever the case of the address" do
        attach(email: "alice.martin@ville.fr")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload(email: "ALICE.Martin@ville.fr")) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq("email" => ["désigne un agent déjà rattaché à cette organisation"])
      end
    end

    # La connexion choisit le rattachement d'après le seul SIRET attesté par ProConnect.
    context "with an agent attached to the SIRET under another insee code" do
      it "refuses on the insee code, distinctly, and writes nothing" do
        attach(email: "alice.martin@ville.fr", insee_code: "75101")
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq(
          "membership" => {"insee_code" => ["diffère de celui sous lequel l'agent est déjà rattaché à ce SIRET"]}
        )
      end
    end

    context "with an invalid request" do
      # La base donne « member » par défaut, jamais un appel.
      it "refuses a missing role and creates no member" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload({}, role: nil)) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"role" => ["doit être rempli(e)"]})
      end

      it "refuses a role other than the two of the V2" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload({}, role: "admin")) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"role" => ["n'est pas inclus(e) dans la liste"]})
      end

      # Un membre sans habilitation n'aurait accès à rien.
      it "refuses a member without habilitation" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

        expect { register(payload({}, data_stream_codes: [])) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["doit compter au moins un code pour un membre"]})
      end

      it "refuses an incomplete identity and a malformed phone, each on its field" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload({first_name: ""}, mobile_phone_number: "06 12")) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq(
          "first_name" => ["doit être rempli(e)"],
          "membership" => {"mobile_phone_number" => ["n'est pas valide"]}
        )
      end

      # Écartée par le filtrage des paramètres, la liste passerait pour absente : tous les flux.
      it "refuses data stream codes sent as a single code, and writes nothing" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

        expect { register(payload({}, role: "local_administrator", data_stream_codes: "CERTDC")) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["doit être une liste de codes"]})
      end

      # Seule une liste vide explicite donne tous les flux à un administrateur local : toute autre
      # forme est refusée, y compris celles que les paramètres de Rails réduiraient à une liste vide.
      {
        "a local administrator without the list" =>
          {role: "local_administrator", codes: {}, reason: "doit être fournie : une liste de codes, vide pour un administrateur local qui a accès à tous les flux"},
        "a local administrator with a misspelled key" =>
          {role: "local_administrator", codes: {data_stream_code: ["CERTDC"]}, reason: "doit être fournie : une liste de codes, vide pour un administrateur local qui a accès à tous les flux"},
        "a local administrator with a null list" =>
          {role: "local_administrator", codes: {data_stream_codes: nil}, reason: "doit être une liste de codes"},
        "a local administrator with a null code" =>
          {role: "local_administrator", codes: {data_stream_codes: [nil]}, reason: "doit être une liste de codes"},
        "a member with a null among its codes" =>
          {role: "member", codes: {data_stream_codes: ["CERTDC", nil]}, reason: "doit être une liste de codes"}
      }.each do |label, request_case|
        it "refuses #{label}, and writes nothing" do
          stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
          body = payload({}, role: request_case[:role])
          body[:agent][:membership].delete(:data_stream_codes)
          body[:agent][:membership].merge!(request_case[:codes])

          expect { register(body) }.not_to change { written }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to eq("membership" => {"data_stream_codes" => [request_case[:reason]]})
        end
      end

      # La liste n'est lue que dans un corps JSON objet : l'agent passé dans l'URL ne la fournit pas.
      {"null" => "null", "a list" => "[]", "a number" => "1", "empty" => ""}.each do |label, raw_body|
        it "refuses a JSON body #{label} with the agent in the query string as a missing list, and writes nothing" do
          stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
          headers = bearer(internal_client).merge("CONTENT_TYPE" => "application/json")

          expect { post "/api/internal/agents?#{payload.to_query}", params: raw_body, headers: }.not_to change { written }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to eq("membership" => {"data_stream_codes" => ["doit être fournie : une liste de codes, vide pour un administrateur local qui a accès à tous les flux"]})
        end
      end

      {"absent" => nil, "not an object" => "21750056000016"}.each do |label, membership|
        it "refuses a membership #{label} on each of its required fields, and writes nothing" do
          body = {agent: {email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin", membership:}.compact}

          expect { register(body) }.not_to change { written }

          expect(response).to have_http_status(:unprocessable_content)
          expect(json).to eq("membership" => {
            "siret" => ["doit être rempli(e)"],
            "insee_code" => ["doit être rempli(e)"],
            "role" => ["doit être rempli(e)"],
            "data_stream_codes" => ["doit être fournie : une liste de codes, vide pour un administrateur local qui a accès à tous les flux"]
          })
        end
      end

      # La borne protège hub-api d'un appel abusif, même interne.
      it "refuses more than 100 distinct data stream codes" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

        expect { register(payload({}, data_stream_codes: Array.new(101) { "FLUX-#{it}" })) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["ne peut pas compter plus de 100 codes distincts"]})
      end

      it "refuses a request without the agent envelope" do
        expect { register(payload[:agent]) }.not_to change { written }

        expect(response).to have_http_status(:bad_request)
        expect(json).to eq("error" => "La demande doit porter l'agent sous la clé « agent ».")
      end
    end

    # Un agent n'est jamais rattaché à une organisation qui n'existe pas.
    context "with an organisation unknown to the referential" do
      it "refuses on the SIRET and leaves the organisation unknown to the V2" do
        stub_hub_api_organization_not_found(siret: "21750056000016")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq(
          "membership" => {"siret" => ["ne désigne, avec ce code INSEE, aucune organisation du référentiel"]}
        )
      end

      it "refuses an organisation the V2 still knows once the referential no longer has it" do
        attach(email: "premier.agent@ville.fr")
        stub_hub_api_organization_not_found(siret: "21750056000016")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq(
          "membership" => {"siret" => ["ne désigne, avec ce code INSEE, aucune organisation du référentiel"]}
        )
      end
    end

    context "with the referential unavailable" do
      it "answers a retryable refusal without Retry-After and writes nothing" do
        stub_hub_api_organization_error(siret: "21750056000016")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:service_unavailable)
        expect(json).to eq("error" => "Le référentiel V1 ne répond pas. Réessayez dans quelques instants.")
        expect(response.headers).not_to have_key("Retry-After")
      end

      it "still answers the reasons already established instead" do
        stub_hub_api_organization_error(siret: "21750056000016")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload({}, phone_number: "abc")) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"phone_number" => ["n'est pas valide"]})
      end

      it "still checks the data stream codes, and answers the unknown ones instead" do
        stub_hub_api_organization_error(siret: "21750056000016")
        stub_hub_api_v2_data_stream_not_found(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["contient un code de flux inconnu du référentiel : « CERTDC »"]})
      end
    end

    # Une habilitation porte sur un flux que hub-api connaît.
    context "with data stream codes checked by hub-api" do
      it "habilitates the agent on exactly the known data streams sent" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")
        stub_hub_api_v2_data_stream(code: "AEC")

        register(payload({}, data_stream_codes: ["CERTDC", "AEC"]))

        expect(response).to have_http_status(:created)
        expect(json["membership"]["data_stream_codes"]).to contain_exactly("CERTDC", "AEC")
        expect(Membership.sole.data_stream_codes).to contain_exactly("CERTDC", "AEC")
      end

      it "refuses an unknown code on the habilitations and writes nothing" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream_not_found(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["contient un code de flux inconnu du référentiel : « CERTDC »"]})
      end

      # L'appelant découvre tous ses codes inconnus en un appel, chacun cité.
      it "refuses the whole request for unknown codes among known ones, citing each of them" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")
        stub_hub_api_v2_data_stream(code: "AEC")
        stub_hub_api_v2_data_stream_not_found(code: "INCONNU")
        stub_hub_api_v2_data_stream_not_found(code: "AUTRE")

        expect { register(payload({}, data_stream_codes: ["CERTDC", "INCONNU", "AEC", "AUTRE"])) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => [
          "contient un code de flux inconnu du référentiel : « INCONNU »",
          "contient un code de flux inconnu du référentiel : « AUTRE »"
        ]})
      end

      it "refuses a code holding a space, without asking hub-api" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        client = use_hub_api_fake_client

        expect { register(payload({}, data_stream_codes: ["CERT\u00A0DC"])) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["contient un code invalide : « CERT\u00A0DC »"]})
        expect(client.requests).to be_empty
      end

      # La gem refuse de placer « .. » dans un chemin : aucun flux ne s'appelle ainsi.
      it "answers a dot segment as an unknown code, without asking hub-api" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        client = use_hub_api_fake_client

        expect { register(payload({}, data_stream_codes: [".."])) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["contient un code de flux inconnu du référentiel : « .. »"]})
        expect(client.requests).to be_empty
      end

      it "answers a retryable refusal when hub-api does not answer, and writes nothing" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream_error(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:service_unavailable)
        expect(json).to eq("error" => "Le référentiel V1 ne répond pas. Réessayez dans quelques instants.")
      end

      # La panne ne masque pas les codes déjà reconnus inconnus.
      it "answers the unknown codes found before hub-api stops answering" do
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream_not_found(code: "INCONNU")
        stub_hub_api_v2_data_stream_error(code: "CERTDC")

        expect { register(payload({}, data_stream_codes: ["INCONNU", "CERTDC"])) }.not_to change { written }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json).to eq("membership" => {"data_stream_codes" => ["contient un code de flux inconnu du référentiel : « INCONNU »"]})
      end
    end

    # Tous les motifs à la fois, chacun sur son champ ; un conflit l'emporte.
    context "with a request refused for several reasons" do
      it "answers the agent already attached with the unknown data stream code" do
        attach(email: "alice.martin@ville.fr")
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream_not_found(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq(
          "email" => ["désigne un agent déjà rattaché à cette organisation"],
          "membership" => {"data_stream_codes" => ["contient un code de flux inconnu du référentiel : « CERTDC »"]}
        )
      end

      it "answers every reason with the conflict status" do
        attach(email: "alice.martin@ville.fr")
        stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload({last_name: ""}, phone_number: "abc")) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq(
          "email" => ["désigne un agent déjà rattaché à cette organisation"],
          "last_name" => ["doit être rempli(e)"],
          "membership" => {"phone_number" => ["n'est pas valide"]}
        )
      end

      it "answers the conflict on the insee code with the organisation unknown to the referential" do
        attach(email: "alice.martin@ville.fr", insee_code: "75101")
        stub_hub_api_organization_not_found(siret: "21750056000016")
        stub_hub_api_v2_data_stream(code: "CERTDC")

        expect { register(payload) }.not_to change { written }

        expect(response).to have_http_status(:conflict)
        expect(json).to eq(
          "membership" => {
            "siret" => ["ne désigne, avec ce code INSEE, aucune organisation du référentiel"],
            "insee_code" => ["diffère de celui sous lequel l'agent est déjà rattaché à ce SIRET"]
          }
        )
      end
    end

    # Hors des adresses admises, l'endpoint n'existe pas, même pour un client qui a le droit.
    context "from an address outside the allowed list" do
      {
        "directly" => {},
        "with a forged X-Forwarded-For" => {"X-Forwarded-For" => "127.0.0.1"}
      }.each do |label, headers|
        it "answers the JSON 404 of an unknown URL and writes nothing (#{label})" do
          expect {
            post "/api/internal/agents", params: payload, as: :json,
              headers: bearer(internal_client).merge(headers), env: {"REMOTE_ADDR" => "203.0.113.10"}
          }.not_to change { written }

          expect(response).to have_http_status(:not_found)
          expect(json).to eq("error" => "Ressource introuvable.")
        end
      end
    end

    context "without a valid token" do
      it "refuses with the uniform 401" do
        expect { post "/api/internal/agents", params: payload, as: :json }.not_to change { written }

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq("error" => "invalid_token")
      end
    end

    context "with a client without the right to register" do
      it "refuses with a 403 distinct from the 401" do
        expect { register(payload, application: create(:oauth_application)) }.not_to change { written }

        expect(response).to have_http_status(:forbidden)
        expect(json).to eq("error" => "Ce client n'a pas le droit d'enregistrer un agent.")
      end

      # Le droit se lit à chaque appel, pas à l'émission du jeton.
      it "refuses as soon as the right is withdrawn, even with a token delivered before" do
        headers = bearer(internal_client)
        OauthApplicationRight.where(oauth_application: internal_client).destroy_all

        expect {
          post "/api/internal/agents", params: payload, headers:, as: :json
        }.not_to change { written }

        expect(response).to have_http_status(:forbidden)
        expect(json).to eq("error" => "Ce client n'a pas le droit d'enregistrer un agent.")
      end
    end
  end
end
