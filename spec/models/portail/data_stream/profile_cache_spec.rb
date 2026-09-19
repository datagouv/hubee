# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DataStream::ProfileCache do
  # Le cache de test est un `null_store` : sans vrai magasin, « lu une seule fois » passerait tout
  # seul et ne prouverait rien. Même motif que le spec des abonnements.
  def with_a_real_cache
    expect(Rails).to receive(:cache).at_least(:once).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  describe ".fetch" do
    it "reads the profile of a data stream" do
      stub_hub_api_v2_data_stream_profile(code: "CERTDC")

      expect(described_class.fetch("CERTDC").code).to eq("CERTDC")
    end

    # Le menu d'états et la validation de la cible le demandent tous deux dans la même requête.
    it "reads the upstream only once for the same data stream" do
      with_a_real_cache
      expect(Portail::HubAPI::DataStreams).to receive(:find).once
        .and_return(build(:portail_data_stream_profile))

      2.times { described_class.fetch("CERTDC") }
    end

    # La clé porte la forme du profil : un membre ajouté met le cache précédent hors jeu sans
    # qu'on ait à y penser.
    it "namespaces its cache key by the shape of what it stores" do
      expect(described_class::CACHE_NAMESPACE).to end_with("code-name-awaiting_documents")
    end

    # Une heure : assez pour ne pas marteler l'amont, assez court pour qu'un paramétrage
    # changé se voie dans la journée.
    it "reads the upstream again once an hour has passed" do
      with_a_real_cache
      expect(Portail::HubAPI::DataStreams).to receive(:find).twice
        .and_return(build(:portail_data_stream_profile))

      described_class.fetch("CERTDC")
      travel(59.minutes) { described_class.fetch("CERTDC") }
      travel(61.minutes) { described_class.fetch("CERTDC") }
    end

    it "reads the upstream again for another data stream" do
      with_a_real_cache
      expect(Portail::HubAPI::DataStreams).to receive(:find).twice
        .and_return(build(:portail_data_stream_profile))

      described_class.fetch("CERTDC")
      described_class.fetch("AEC")
    end

    it "returns nothing when the upstream is unavailable" do
      expect(Portail::HubAPI::DataStreams).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

      expect(described_class.fetch("CERTDC")).to be_nil
    end

    it "returns nothing when the data stream is unknown upstream" do
      expect(Portail::HubAPI::DataStreams).to receive(:find).and_raise(Portail::HubAPI::NotFound)

      expect(described_class.fetch("INCONNU")).to be_nil
    end

    # Une lecture qui échoue ne se met pas en cache : la suivante retente, sinon une panne d'une
    # seconde priverait l'agent de son menu pendant une heure.
    it "does not remember a failure" do
      with_a_real_cache
      expect(Portail::HubAPI::DataStreams).to receive(:find).twice
        .and_raise(Portail::HubAPI::Unavailable)

      2.times { described_class.fetch("CERTDC") }
    end
  end
end
