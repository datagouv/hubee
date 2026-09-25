# frozen_string_literal: true

require "rails_helper"

# Contre le FakeClient : la trace s'observe dans l'historique qu'il tient, et son absence aussi.
RSpec.describe Portail::Deliveries::Archives::Show::Download do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:delivery) do
    build(:portail_delivery, id: delivery_id, attachments: [
      build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111", filename: "certificat.pdf"),
      build(:portail_attachment, id: "a2222222-2222-2222-2222-222222222222", filename: "flux.xml")
    ])
  end
  let(:membership) do
    build(:membership, agent: create(:agent, first_name: "Alice", last_name: "Martin"),
      organization_link: build(:organization_link, siret: "12345678901234", insee_code: "75056"))
  end

  def serve_delivery
    client = use_hub_api_fake_client
    client.add_case(build_v2_delivery(id: delivery_id,
      recipient: build_v2_recipient(siret: "12345678901234", code_insee: "75056"),
      data_package: build_v2_data_package(attachments: delivery.attachments.map { |attachment|
        build_v2_attachment(id: attachment.id)
      })))
    client
  end

  def history(client)
    HubApiV1::V2::Delivery.find(id: delivery_id, siret: "12345678901234", code_insee: "75056",
      client: client).events
  end

  def fetch(membership: self.membership)
    travel_to(Time.utc(2026, 9, 23, 12, 5)) { described_class.call(delivery: delivery, membership: membership) }
  end

  def entries(archive)
    Zip::File.open(archive.path) do |zip|
      zip.entries.map { |entry| [entry.name.dup.force_encoding(Encoding::UTF_8), entry.get_input_stream.read.b] }
    end
  end

  def watch_tempfile_paths
    paths = []
    expect(Tempfile).to receive(:new).and_wrap_original do |new, *args, **options|
      new.call(*args, **options).tap { |file| paths << file.path }
    end
    paths
  end

  # Le nom suit l'heure du clic, à Paris ; la trace le porte et part signée de l'agent de la session.
  # Le journal donne les identifiants, pas les noms : la supervision tourne sans donnée personnelle.
  it "hands back the archive of the received pieces, named after the click, traced and logged once" do
    stem = "20260923-14.05_DGS-CERTDC-0000000000001-01"
    first_id, second_id = delivery.attachments.map(&:id)
    client = serve_delivery
    client.add_attachment_content(attachment_id: first_id, body: "%PDF-1.7\n\xFF\xFE\x00binaire".b)
    client.add_attachment_content(attachment_id: second_id, body: "<xml/>".b)
    previous_events = history(client)

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_success
    expect(result.archive_filename).to eq("#{stem}.zip")
    expect(entries(result.archive)).to eq([
      ["#{stem}/certificat.pdf", "%PDF-1.7\n\xFF\xFE\x00binaire".b],
      ["#{stem}/flux.xml", "<xml/>".b]
    ])
    expect(history(client) - previous_events).to contain_exactly(have_attributes(
      event_type: :"attachment.all_downloaded", content: "#{stem}.zip", author: "Alice MARTIN"
    ))
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièces récupérées en archive",
      payload_includes: {delivery_id: delivery_id, agent_id: membership.agent.id, attachment_ids: [first_id, second_id]}
    ))
  ensure
    result&.archive&.close!
  end

  it "serves nothing, and asks nothing of the upstream, for an agent without a name" do
    client = serve_delivery
    nameless = build(:membership, agent: create(:agent, first_name: nil, last_name: nil),
      organization_link: membership.organization_link)
    expect(Tempfile).not_to receive(:new)

    result = fetch(membership: nameless)

    expect(result).to be_failure
    expect(result.error).to eq(:unknown_author)
    expect(client.requests).to be_empty
  end

  # Pas d'archive partielle : une pièce reçue que l'amont ne sert pas, et rien ne reste.
  it "fails as content unavailable, untraced and without archive, when the upstream serves no content" do
    client = serve_delivery
    previous_events = history(client)
    first_id, second_id = delivery.attachments.map(&:id)
    stub_hub_api_v2_attachment_downloaded(first_id)
    stub_hub_api_v2_attachment_unavailable(second_id)
    paths = watch_tempfile_paths

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:content_unavailable)
    expect(result.archive).to be_nil
    expect(history(client)).to eq(previous_events)
    expect(File.exist?(paths.first)).to be(false)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Archive non remise", payload_includes: {delivery_id: delivery_id, reason: :content_unavailable}
    ))
  end

  it "fails as event limit reached, untraced and without archive, when the history is full" do
    client = serve_delivery
    client.saturate_case(delivery_id)
    full = history(client)
    paths = watch_tempfile_paths

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:event_limit_reached)
    expect(history(client)).to eq(full)
    expect(File.exist?(paths.first)).to be(false)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Historique du télédossier saturé", payload_includes: {delivery_id: delivery_id}
    ))
  end

  # L'inventaire disait reçue, l'amont ne la sert plus : l'inventaire a vieilli.
  it "fails as not found, logged under its own reason, when the upstream no longer serves a piece" do
    client = serve_delivery
    previous_events = history(client)
    stub_hub_api_v2_attachment_not_found(delivery.attachments.first.id)

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(history(client)).to eq(previous_events)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Archive non livrable", payload_includes: {delivery_id: delivery_id, reason: :gone_upstream}
    ))
  end

  # Le télédossier a quitté le périmètre de l'organisation entre le détail et le clic : l'amont
  # sert encore les pièces, mais refuse la trace.
  it "fails as not found, untraced and without archive, when the upstream refuses the trace" do
    client = use_hub_api_fake_client
    client.add_case(build_v2_delivery(id: delivery_id,
      recipient: build_v2_recipient(siret: "98765432109876", code_insee: "75056"),
      data_package: build_v2_data_package(attachments: delivery.attachments.map { |attachment|
        build_v2_attachment(id: attachment.id)
      })))
    previous_events = HubApiV1::V2::Delivery.find(id: delivery_id, siret: "98765432109876",
      code_insee: "75056", client: client).events
    paths = watch_tempfile_paths

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(result.archive).to be_nil
    expect(HubApiV1::V2::Delivery.find(id: delivery_id, siret: "98765432109876", code_insee: "75056",
      client: client).events).to eq(previous_events)
    expect(File.exist?(paths.first)).to be(false)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Archive non livrable", payload_includes: {delivery_id: delivery_id, reason: :gone_upstream}
    ))
  end

  it "fails as unavailable, logged, when the upstream fails on a content" do
    client = serve_delivery
    previous_events = history(client)
    stub_hub_api_v2_attachment_error(delivery.attachments.first.id)

    result = nil
    events = capture_semantic_logger_events { result = fetch }

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(history(client)).to eq(previous_events)
    expect(events).to include(be_a_semantic_logger_event(
      level: :error, message: "Archive indisponible",
      payload_includes: {delivery_id: delivery_id, error: "Portail::HubAPI::Unavailable"}
    ))
  end
end
