# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour le contenu des pièces : les octets ET la trace de leur
# récupération, sous un seul nom. Succès, « non trouvé » et saturation s'éprouvent de bout en bout
# contre le FakeClient ; le contenu non servi et la panne, qu'il ne sait pas produire faute de
# stockage, par bouchon de classe.
RSpec.describe Portail::HubAPI::Attachments do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:attachment_id) { "b7e3c2a0-5d1f-4c8e-9a6b-3f2e1d0c9b8a" }
  # Ce que la trace porte, invariable d'un exemple à l'autre : seuls les exemples qui l'éprouvent
  # citent ces valeurs.
  let(:trace) do
    {filename: "certificat.pdf", author: "Alice Martin", siret: "12345678901234", insee_code: "75056"}
  end

  # Un dossier que le fake sert vraiment, avec les pièces demandées dedans — et servi à
  # l'organisation qui trace : le verbe d'écriture rejoue cette borne avant d'écrire.
  def add_served_case(client, attachment_ids = [attachment_id])
    client.add_case(build_v2_delivery(id: delivery_id,
      recipient: build_v2_recipient(siret: trace[:siret], code_insee: trace[:insee_code]),
      data_package: build_v2_data_package(attachments: attachment_ids.map { |id| build_v2_attachment(id: id) })))
  end

  # Aucune exception de la gem ne doit survivre à cette couche. Seule la panne est signalée : un
  # robot qui balaie des adresses ne doit pas noyer la supervision.
  content_errors = {
    "an attachment the upstream does not serve" => {
      raised: HubApiV1::V2::AttachmentNotFoundError, translated: Portail::HubAPI::NotFound, reported: false
    },
    "an identifier the upstream refuses" => {
      raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest, reported: false
    },
    "a content the upstream could not serve" => {
      raised: HubApiV1::V2::AttachmentUnavailableError, translated: Portail::HubAPI::ContentUnavailable,
      reported: false
    },
    # Le compte du portail n'est pas autorisé sur la route : un incident d'exploitation, pas une
    # situation à expliquer à l'agent.
    "a configuration refusal" => {
      raised: HubApiV1::Client::ForbiddenError, translated: Portail::HubAPI::Unavailable, reported: true
    },
    "a transport failure" => {
      raised: HubApiV1::Client::Error, translated: Portail::HubAPI::Unavailable, reported: true
    },
    "an upstream error of any other family" => {
      raised: HubApiV1::Error, translated: Portail::HubAPI::Unavailable, reported: true
    }
  }

  # L'écriture a son propre rescue, et ses propres refus : ce qui survient APRÈS les octets se
  # traduit comme ce qui survient avant, sans quoi une panne de la trace passerait pour un fichier
  # absent.
  trace_errors = {
    "a delivery whose history is full" => {
      raised: HubApiV1::V2::DeliveryEventLimitReachedError,
      translated: Portail::HubAPI::EventLimitReached, reported: false
    },
    # La garde de périmètre que le verbe rejoue avant d'écrire : le dossier a disparu, ou n'a
    # jamais été celui de cette organisation.
    "a delivery the upstream refuses to serve" => {
      raised: HubApiV1::V2::DeliveryNotFoundError, translated: Portail::HubAPI::NotFound, reported: false
    },
    "a trace the upstream refuses before any call" => {
      raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest, reported: false
    },
    "a transport failure on the write" => {
      raised: HubApiV1::Client::Error, translated: Portail::HubAPI::Unavailable, reported: true
    }
  }

  describe ".download" do
    # Des octets qui ne sont pas de l'UTF-8 valide : un ré-encodage en route se verrait.
    it "returns the bytes of the attachment untouched" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      body = "%PDF-1.7\n\xFF\xFE\x00binaire".b
      client.add_attachment_content(attachment_id: attachment_id, body: body)

      content = described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)

      expect(content).to eq(body)
      expect(content.encoding).to eq(Encoding::BINARY)
    end

    # L'invariant du chantier : les octets reviennent ET l'historique du dossier a gagné la trace.
    # Il s'éprouve contre le fake, pas par bouchon — c'est l'écriture réelle qui compte.
    it "records the retrieval in the history of the delivery" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)

      history = HubApiV1::V2::Delivery.find(id: delivery_id, siret: trace[:siret],
        code_insee: trace[:insee_code], client: client).events
      expect(history.last).to have_attributes(event_type: :"attachment.downloaded",
        content: "certificat.pdf", author: "Alice Martin")
    end

    # Hash complet : un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Attachment).to receive(:download).with(
        delivery_id: delivery_id, id: attachment_id, client: client
      ).and_return("octets".b)
      # `notify: false` est une décision, pas un défaut hérité : elle se lit au site d'appel.
      expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download).with(
        id: delivery_id, filename: "certificat.pdf", author: "Alice Martin",
        siret: "12345678901234", code_insee: "75056", notify: false, client: client
      ).and_return(build_v2_event)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Attachment).to receive(:download).with(
        delivery_id: delivery_id, id: attachment_id, client: shared
      ).and_return("octets".b)
      # `hash_including` : le hash complet est éprouvé par l'exemple précédent ; celui-ci ne porte
      # que sur le client servi par défaut.
      expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download)
        .with(hash_including(client: shared)).and_return(build_v2_event)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
    end

    # « Pas de trace, pas de fichier » : l'écriture refusée, l'appelant n'obtient rien. Le dossier
    # plein est un état durable de l'amont, pas un incident — rien ne part vers la supervision.
    it "serves nothing when the history of the delivery is full" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      client.saturate_case(delivery_id)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)
      }.to raise_error(Portail::HubAPI::EventLimitReached)
    end

    # L'ordre est le contrat : sans octets, rien à tracer — une pièce que l'amont ne sert pas ne
    # doit pas consommer un des emplacements d'événements du dossier.
    it "writes no trace when the content itself could not be served" do
      use_hub_api_fake_client
      stub_hub_api_v2_attachment_unavailable(attachment_id)
      expect(HubApiV1::V2::Delivery).not_to receive(:record_attachment_download)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
      }.to raise_error(Portail::HubAPI::ContentUnavailable)
    end

    # Rien n'est bouchonné : c'est le vrai « non trouvé » de l'amont qui doit se produire. Le
    # journal, au message stable, porte ce qui situe la pièce et rien d'autre.
    it "lets an attachment the delivery does not carry reach the upstream refusal, logged, unreported" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      missing_id = "c9d8e7f6-1a2b-4c3d-8e4f-5a6b7c8d9e0f"
      expect(Rails.logger).to receive(:warn).with("Pièce introuvable chez l'amont",
        delivery_id: delivery_id, attachment_id: missing_id)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.download(delivery_id: delivery_id, id: missing_id, **trace, client: client)
      }.to raise_error(Portail::HubAPI::NotFound)
    end

    it "lets an identifier that is not a UUID reach the upstream refusal before any call" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.download(delivery_id: delivery_id, id: "..", **trace, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end

    # Le seul signal d'une panne de la route de contenu, que l'amont confond avec une pièce
    # purgée : une ligne au message stable, comptable en agrégat, sans rapport d'erreur.
    it "logs an unserved content with what locates it, unreported" do
      use_hub_api_fake_client
      stub_hub_api_v2_attachment_unavailable(attachment_id)
      expect(Rails.logger).to receive(:warn).with("Contenu de pièce non servi par l'amont",
        delivery_id: delivery_id, attachment_id: attachment_id)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
      }.to raise_error(Portail::HubAPI::ContentUnavailable)
    end

    content_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Attachment).to receive(:download).and_raise(error[:raised])
        if error[:reported]
          expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
        else
          expect(Rails.error).not_to receive(:report)
        end

        expect {
          described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
        }.to raise_error(error[:translated])
      end
    end

    trace_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Attachment).to receive(:download).and_return("octets".b)
        expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download).and_raise(error[:raised])
        if error[:reported]
          expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
        else
          expect(Rails.error).not_to receive(:report)
        end

        expect {
          described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
        }.to raise_error(error[:translated])
      end
    end
  end

  describe ".download_all" do
    let(:archive_trace) { trace.except(:filename).merge(archive_filename: "20260923-14.05_DOSSIER-42.zip") }

    def content_path(id) = "#{HubApiV1::Case::PATH}/#{delivery_id}/attachments/#{id}"

    def events_path = "#{HubApiV1::Case::PATH}/#{delivery_id}/events"

    def content_requests(client) = client.requests.count { |request| request.verb == :get_binary }

    def recorded_events(client)
      HubApiV1::V2::Delivery.find(id: delivery_id, siret: trace[:siret], code_insee: trace[:insee_code],
        client: client).events
    end

    def entries_of(archive)
      Zip::File.open(archive.path) do |zip|
        zip.entries.map { |entry| {name: entry.name, body: entry.get_input_stream.read} }
      end
    end

    def intercept_archive(&on_archive)
      expect(Portail::Archive).to receive(:new).and_wrap_original { |new, *args| new.call(*args).tap(&on_archive) }
    end

    # La taille du fichier temporaire au moment de sa suppression.
    def watch_size_at_deletion
      sizes = []
      expect(Tempfile).to receive(:new).and_wrap_original do |new, *args, **options|
        new.call(*args, **options).tap { |file| record_size_at_deletion(file, sizes) }
      end
      sizes
    end

    def record_size_at_deletion(file, sizes)
      expect(file).to receive(:close!).and_wrap_original do |close|
        sizes << File.size(file.path)
        close.call
      end
    end

    context "with two received attachments" do
      let(:delivery) do
        build(:portail_delivery, id: delivery_id, attachments: [
          build(:portail_attachment, id: attachment_id, filename: "certificat.pdf"),
          build(:portail_attachment, id: "d4c3b2a1-6e5f-4a7b-8c9d-0e1f2a3b4c5d", filename: "annexe.xml")
        ])
      end

      # L'invariant du chantier, contre le fake : les lectures dans l'ordre, puis une seule écriture,
      # et seulement après la dernière.
      it "records a single trace of all attachments, after the last content only" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))

        described_class.download_all(delivery: delivery, **archive_trace, client: client).close!

        watched = delivery.attachments.map { |attachment| content_path(attachment.id) } + [events_path]
        expect(client.requests.map(&:path).select { |path| watched.include?(path) }).to eq(watched)
        expect(recorded_events(client).last).to have_attributes(event_type: :"attachment.all_downloaded",
          content: "20260923-14.05_DOSSIER-42.zip", author: "Alice Martin", metadata: {})
      end

      # Une pièce écrite avant que la suivante ne soit lue : jamais deux en mémoire.
      it "writes each content to the archive before reading the next one" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        reads_at_write = []
        intercept_archive do |archive|
          expect(archive).to receive(:add).twice.and_wrap_original do |add, *add_args|
            reads_at_write << content_requests(client)
            add.call(*add_args)
          end
        end

        described_class.download_all(delivery: delivery, **archive_trace, client: client).close!

        expect(reads_at_write).to eq([1, 2])
      end

      # Rendue à l'allocateur dès son écriture : la pièce suivante ne s'ajoute pas à elle en mémoire.
      it "empties each content once written to the archive" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        contents = ["premier".b, "second".b]
        delivery.attachments.zip(contents) do |attachment, content|
          expect(HubApiV1::V2::Attachment).to receive(:download)
            .with(delivery_id: delivery_id, id: attachment.id, client: client).and_return(content)
        end

        described_class.download_all(delivery: delivery, **archive_trace, client: client).close!

        expect(contents).to all(be_empty)
      end

      it "leaves a frozen content as it is" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        expect(HubApiV1::V2::Attachment).to receive(:download).twice.and_return("octets".b.freeze)

        archive = described_class.download_all(delivery: delivery, **archive_trace, client: client)

        expect(entries_of(archive).map { |entry| entry[:body] }).to eq(%w[octets octets])
      ensure
        archive&.close!
      end

      # Hash complet : un paramètre inattendu doit se voir. L'auteur part tel quel.
      it "sends the portal vocabulary as the upstream keywords" do
        client = HubApiV1::Testing::FakeClient.new
        delivery.attachments.each do |attachment|
          expect(HubApiV1::V2::Attachment).to receive(:download)
            .with(delivery_id: delivery_id, id: attachment.id, client: client).ordered.and_return("octets".b)
        end
        # `notify: false` est une décision, pas un défaut hérité : elle se lit au site d'appel.
        expect(HubApiV1::V2::Delivery).to receive(:record_all_attachments_download).with(
          id: delivery_id, filename: "20260923-14.05_DOSSIER-42.zip", author: "Alice Martin",
          siret: "12345678901234", code_insee: "75056", notify: false, client: client
        ).ordered.and_return(build_v2_event)

        described_class.download_all(delivery: delivery, **archive_trace, client: client).close!
      end

      it "hands the gem its shared client when none is injected" do
        shared = use_hub_api_fake_client
        delivery.attachments.each do |attachment|
          expect(HubApiV1::V2::Attachment).to receive(:download)
            .with(delivery_id: delivery_id, id: attachment.id, client: shared).ordered.and_return("octets".b)
        end
        # `hash_including` : le hash complet est éprouvé par l'exemple précédent ; celui-ci ne porte
        # que sur le client servi par défaut.
        expect(HubApiV1::V2::Delivery).to receive(:record_all_attachments_download)
          .with(hash_including(client: shared)).ordered.and_return(build_v2_event)

        described_class.download_all(delivery: delivery, **archive_trace).close!
      end

      # Pas d'archive partielle : la pièce déjà écrite disparaît avec le fichier.
      it "stops at a content the upstream does not serve, untraced, and deletes the archive" do
        client = use_hub_api_fake_client
        add_served_case(client, delivery.attachments.map(&:id))
        stub_hub_api_v2_attachment_downloaded(attachment_id)
        stub_hub_api_v2_attachment_unavailable(delivery.attachments.last.id)
        paths = watch_tempfile_paths

        expect {
          described_class.download_all(delivery: delivery, **archive_trace)
        }.to raise_error(Portail::HubAPI::ContentUnavailable)
        expect(client.requests_to(events_path)).to be_empty
        expect(paths.size).to eq(1)
        expect(File.exist?(paths.first)).to be(false)
      end

      it "stops at a content the upstream fails to read, reported, untraced, and deletes the archive" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        paths = watch_tempfile_paths
        expect(HubApiV1::V2::Attachment).to receive(:download).and_raise(HubApiV1::Client::Error)
        expect(Rails.error).to receive(:report).with(instance_of(HubApiV1::Client::Error), handled: true)

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, client: client)
        }.to raise_error(Portail::HubAPI::Unavailable)
        expect(client.requests_to(events_path)).to be_empty
        expect(File.exist?(paths.first)).to be(false)
      end

      # La copie du descripteur tenue par rubyzip garderait sinon l'espace disque jusqu'au GC.
      it "empties the archive before deleting it when the writing stops" do
        use_hub_api_fake_client
        stub_hub_api_v2_attachment_downloaded(attachment_id, body: Random.new(42).bytes(2 * Portail::Archive::CHUNK_SIZE))
        stub_hub_api_v2_attachment_unavailable(delivery.attachments.last.id)
        sizes = watch_size_at_deletion

        expect {
          described_class.download_all(delivery: delivery, **archive_trace)
        }.to raise_error(Portail::HubAPI::ContentUnavailable)
        expect(sizes).to eq([0])
      end

      # Rien n'est bouchonné : c'est le vrai « non trouvé » de l'amont qui doit se produire.
      it "lets an attachment the delivery does not carry reach the upstream refusal, untraced" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, [attachment_id])
        paths = watch_tempfile_paths
        expect(Rails.error).not_to receive(:report)

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, client: client)
        }.to raise_error(Portail::HubAPI::NotFound)
        expect(client.requests_to(content_path(delivery.attachments.last.id))).not_to be_empty
        expect(client.requests_to(events_path)).to be_empty
        expect(File.exist?(paths.first)).to be(false)
      end

      # Un état durable de l'amont, pas un incident : rien ne part vers la supervision. Le fake
      # journalise le POST avant de le refuser : c'est l'historique relu qui prouve l'absence de trace.
      it "refuses a delivery whose history is full, unreported, untraced and without archive" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        client.saturate_case(delivery_id)
        full = recorded_events(client).size
        paths = watch_tempfile_paths
        expect(Rails.error).not_to receive(:report)

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, client: client)
        }.to raise_error(Portail::HubAPI::EventLimitReached)
        expect(recorded_events(client).size).to eq(full)
        expect(File.exist?(paths.first)).to be(false)
      end

      # L'écriture refuse un dossier hors du périmètre de l'organisation, avant tout POST.
      it "refuses a delivery outside the perimeter at the write, unreported, untraced and without archive" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        paths = watch_tempfile_paths
        expect(Rails.error).not_to receive(:report)

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, siret: "98765432109876",
            client: client)
        }.to raise_error(Portail::HubAPI::NotFound)
        expect(client.requests_to(events_path)).to be_empty
        expect(File.exist?(paths.first)).to be(false)
      end

      # Une erreur qui n'est pas de la gem (disque plein…) remonte telle quelle, sans trace.
      it "deletes the archive and writes no trace when writing the archive fails" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        paths = watch_tempfile_paths
        intercept_archive { |archive| expect(archive).to receive(:add).and_raise(Errno::ENOSPC) }

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, client: client)
        }.to raise_error(Errno::ENOSPC)
        expect(client.requests_to(events_path)).to be_empty
        expect(File.exist?(paths.first)).to be(false)
      end

      # Le répertoire central s'écrit à la fermeture : un zip qui n'a pas pu se fermer n'est pas remis,
      # donc pas tracé.
      it "deletes the archive and writes no trace when closing the archive fails" do
        client = HubApiV1::Testing::FakeClient.new
        add_served_case(client, delivery.attachments.map(&:id))
        paths = watch_tempfile_paths
        expect(Zip::OutputStream).to receive(:new).and_wrap_original do |new, *args, **options|
          new.call(*args, **options).tap { |zip| expect(zip).to receive(:close_buffer).and_raise(Errno::ENOSPC) }
        end

        expect {
          described_class.download_all(delivery: delivery, **archive_trace, client: client)
        }.to raise_error(Errno::ENOSPC)
        expect(client.requests_to(events_path)).to be_empty
        expect(File.exist?(paths.first)).to be(false)
      end

      trace_errors.each do |situation, error|
        it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
          use_hub_api_fake_client
          paths = watch_tempfile_paths
          expect(HubApiV1::V2::Attachment).to receive(:download).twice.and_return("octets".b)
          expect(HubApiV1::V2::Delivery).to receive(:record_all_attachments_download).and_raise(error[:raised])
          if error[:reported]
            expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
          else
            expect(Rails.error).not_to receive(:report)
          end

          expect {
            described_class.download_all(delivery: delivery, **archive_trace)
          }.to raise_error(error[:translated])
          expect(File.exist?(paths.first)).to be(false)
        end
      end
    end

    # Le nommage des entrées appartient à Portail::Archive : ici, l'ordre et le tri des pièces.
    it "returns the zip of the received attachments only, in their order, rewound" do
      client = HubApiV1::Testing::FakeClient.new
      received_id = "d4c3b2a1-6e5f-4a7b-8c9d-0e1f2a3b4c5d"
      pending_id = "b0000000-0000-0000-0000-000000000000"
      add_served_case(client, [attachment_id, pending_id, received_id])
      client.add_attachment_content(attachment_id: attachment_id, body: "%PDF-1.7\n\xFF\xFE\x00premier".b)
      client.add_attachment_content(attachment_id: received_id, body: "<annexe/>".b)
      delivery = build(:portail_delivery, id: delivery_id, attachments: [
        build(:portail_attachment, id: attachment_id, filename: "certificat.pdf"),
        build(:portail_attachment, id: pending_id, state: "pending"),
        build(:portail_attachment, id: received_id, filename: "annexe.xml")
      ])

      archive = described_class.download_all(delivery: delivery, **archive_trace, client: client)

      expect(archive).to be_a(Tempfile)
      expect(archive).to be_binmode
      expect(archive.pos).to eq(0)
      expect(entries_of(archive)).to eq([
        {name: "20260923-14.05_DOSSIER-42/certificat.pdf", body: "%PDF-1.7\n\xFF\xFE\x00premier".b},
        {name: "20260923-14.05_DOSSIER-42/annexe.xml", body: "<annexe/>".b}
      ])
      expect(client.requests_to(content_path(pending_id))).to be_empty
    ensure
      archive&.close!
    end

    # La liste s'arrête sur l'identifiant refusé : la pièce d'avant a été lue, rien n'est tracé.
    it "stops at an identifier that is not a UUID, untraced, and deletes the archive" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      delivery = build(:portail_delivery, id: delivery_id,
        attachments: [build(:portail_attachment, id: attachment_id), build(:portail_attachment, id: "..")])
      paths = watch_tempfile_paths

      expect {
        described_class.download_all(delivery: delivery, **archive_trace, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests.map(&:path)).to eq([content_path(attachment_id)])
      expect(File.exist?(paths.first)).to be(false)
    end

    # Une archive vide ne se trace pas : l'appelant répond introuvable avant d'en arriver là.
    it "refuses a delivery without any received attachment before any call" do
      client = HubApiV1::Testing::FakeClient.new
      delivery = build(:portail_delivery, id: delivery_id, attachments: [build(:portail_attachment, state: "rejected")])
      expect(Tempfile).not_to receive(:new)

      expect {
        described_class.download_all(delivery: delivery, **archive_trace, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end
  end
end
