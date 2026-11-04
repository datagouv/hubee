# frozen_string_literal: true

require "rails_helper"

# Les rattachements sont en base ; seuls les noms de flux viennent de l'amont, par les
# abonnements de l'organisation, bouchonnés à Portail::HubAPI.
RSpec.describe "Portail::Memberships", type: :request do
  def rows
    Nokogiri::HTML(response.body).css("table tbody tr").map do |row|
      row.css("td").map { |cell| cell.text.squish }
    end
  end

  def local_link
    OrganizationLink.find_by!(siret: ProConnectTestHelper::TEST_SIRET, insee_code: ProConnectTestHelper::TEST_INSEE_CODE)
  end

  # L'agent connecté s'appelle Alex Martin : la connexion synchronise l'identité que sert ProConnect.
  def colleague(first_name: "Alice", last_name: "Bernard", **attributes)
    agent = create(:agent, first_name:, last_name:)
    create(:membership, agent:, organization_link: local_link, **attributes)
  end

  describe "GET /agents" do
    it "redirects a signed-out visitor to the home page" do
      get "/agents"

      expect(response).to redirect_to(root_path)
    end

    # Le rôle × habilitation entier : seul le rôle ouvre la page, et l'habilitation ne restreint
    # pas ce qu'elle montre.
    context "reading perimeter" do
      it "lists every agent of the organisation to a local administrator habilitated on one data stream" do
        sign_in_local_administrator(data_stream_codes: ["CERTDC"])
        colleague
        stub_organisation_subscriptions

        get "/agents"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["BERNARD Alice", "MARTIN Alex"])
      end

      it "lists every agent of the organisation to a local administrator without habilitation" do
        sign_in_local_administrator
        colleague
        stub_organisation_subscriptions

        get "/agents"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["BERNARD Alice", "MARTIN Alex"])
      end

      # Une 404 comme une page inexistante, le refus journalisé ; ni la base ni l'amont ne sont lus.
      it "refuses the page to a member habilitated on a data stream" do
        agent = sign_in_member(data_stream_codes: ["CERTDC"])
        expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

        events = capture_semantic_logger_events { get "/agents" }

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
        expect(events).to include(be_a_semantic_logger_event(
          level: :info, message: "Décision d'accès",
          payload_includes: {
            event: "Portail::Access::Refusal", reason: :out_of_perimeter, path: "/agents",
            agent_id: agent.id, membership_id: Membership.find_by!(agent: agent).id
          }
        ))
      end

      it "refuses the page to a member without habilitation" do
        sign_in_member(data_stream_codes: [])
        expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

        get "/agents"

        expect(response).to have_http_status(:not_found)
        expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
      end

      # Seul le code INSEE sépare les deux organisations.
      it "excludes an agent of another organisation sharing the SIRET" do
        sign_in_local_administrator
        outsider = create(:agent, first_name: "Zoé", last_name: "Ailleurs")
        create(:membership, agent: outsider,
          organization_link: OrganizationLink.create!(siret: ProConnectTestHelper::TEST_SIRET, insee_code: "00002"))
        stub_organisation_subscriptions

        get "/agents"

        expect(response).to have_http_status(:success)
        expect(rows.map(&:first)).to eq(["MARTIN Alex"])
      end

      # Une seule ligne, et ce que dit le rattachement local, pas celui d'ailleurs.
      it "shows an agent attached elsewhere too with the local membership only" do
        sign_in_local_administrator
        local = colleague(job_title: "Juriste")
        create(:membership, :local_administrator, agent: local.agent, job_title: "Ailleurs")
        stub_organisation_subscriptions

        get "/agents"

        expect(response).to have_http_status(:success)
        expect(rows.map { |row| row.values_at(0, 2, 4) })
          .to eq([["BERNARD Alice", "Juriste", "Membre"], ["MARTIN Alex", "—", "Administrateur local"]])
      end
    end

    it "shows every field of an agent" do
      administrator = sign_in_local_administrator
      member = colleague(phone_number: "01 23 45 67 89", job_title: "Juriste")
      member.agent.update!(email: "alice.bernard@example.gouv.fr")
      create(:data_stream_access, membership: member, data_stream_code: "CERTDC")
      stub_organisation_subscriptions
      signed_in_at = Membership.find_by!(agent: administrator).last_signed_in_at

      get "/agents"

      expect(response).to have_http_status(:success)
      expect(rows).to eq([
        ["BERNARD Alice", "alice.bernard@example.gouv.fr", "Juriste", "+33123456789", "Membre",
          "Certificat de décès électronique", "Jamais"],
        ["MARTIN Alex", administrator.email, "—", "—", "Administrateur local",
          "Tous les flux", I18n.l(signed_in_at, format: :long)]
      ])
    end

    # NULL en dernier : un agent dont l'import n'a pas donné le nom ne passe pas devant.
    it "sorts agents by last name, then first name, then email" do
      sign_in_local_administrator
      colleague(first_name: "Alice", last_name: "Bernard")
      colleague(first_name: "Zoé", last_name: "Arnaud")
      colleague(first_name: "Bruno", last_name: "Arnaud")
      colleague(first_name: nil, last_name: nil)
      stub_organisation_subscriptions

      get "/agents"

      expect(response).to have_http_status(:success)
      expect(rows.map(&:first)).to eq(["ARNAUD Bruno", "ARNAUD Zoé", "BERNARD Alice", "MARTIN Alex", "—"])
    end

    # Une information d'affichage : sans les abonnements, les codes seuls, et aucune
    # habilitation accusée d'être hors abonnement.
    it "still lists agents when the subscriptions cannot be read" do
      sign_in_local_administrator(data_stream_codes: ["CERTDC"])
      expect(Portail::HubAPI::Subscriptions).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

      get "/agents"

      expect(response).to have_http_status(:success)
      expect(rows.map { |row| row[5] }).to eq(["CERTDC"])
      expect(Capybara.string(response.body)).not_to have_css(".membership-data-streams__unsubscribed")
    end
  end

  # L'entrée de menu suit la policy : un membre ne voit pas un lien qui le mènerait à une 404.
  # Le rôle × habilitation entier, chaque case posée : aucune ne se déduit d'une autre. Le membre
  # sans habilitation ne fait pas lire de télédossiers, sa page porte quand même le menu.
  describe "header navigation" do
    {
      "a member habilitated on a data stream" => {role: :member, codes: ["CERTDC"], offered: false, lists_deliveries: true},
      "a member without habilitation" => {role: :member, codes: [], offered: false, lists_deliveries: false},
      "a local administrator habilitated on a data stream" => {role: :local_administrator, codes: ["CERTDC"], offered: true, lists_deliveries: true},
      "a local administrator without habilitation" => {role: :local_administrator, codes: [], offered: true, lists_deliveries: true}
    }.each do |agent, setup|
      it "#{setup[:offered] ? "offers" : "does not offer"} the agents to #{agent}" do
        if setup[:role] == :member
          sign_in_member(data_stream_codes: setup[:codes])
        else
          sign_in_local_administrator(data_stream_codes: setup[:codes])
        end
        stub_organisation_subscriptions
        if setup[:lists_deliveries]
          expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(build(:portail_delivery_list))
        end

        get "/teledossiers"

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_css("nav.fr-nav a[href='/teledossiers']", text: "Télédossiers")
        if setup[:offered]
          expect(Capybara.string(response.body)).to have_css("nav.fr-nav a[href='/agents']", text: "Agents")
        else
          expect(Capybara.string(response.body)).not_to have_link("Agents")
        end
      end
    end
  end
end
