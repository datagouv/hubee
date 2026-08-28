# frozen_string_literal: true

require "rails_helper"

# Ce que le query object décide — l'état par défaut, la taille de page, le court-circuit d'un
# périmètre vide, et d'où vient le couple qui identifie l'organisation. Le dialogue avec
# l'amont est éprouvé une seule fois, dans le spec de Portail::HubAPI.
RSpec.describe Portail::DeliveriesQuery do
  let(:organization_link) { create(:organization_link, siret: "22770001000019", insee_code: "77372") }
  let(:membership) { create(:membership, organization_link: organization_link) }

  describe "#call" do
    # Le couple identifie l'organisation à lui seul et l'amont ne vérifie rien à notre place :
    # il doit venir du rattachement. Sans cet exemple, une régression qui le prendrait ailleurs
    # — un paramètre de requête — ouvrirait le périmètre d'une autre structure.
    it "takes the organisation perimeter and the defaults from the membership" do
      expect(Portail::HubAPI::Deliveries).to receive(:list).with(
        siret: "22770001000019", insee_code: "77372", state: "transmitted",
        data_stream_codes: [], page: 1, per_page: 25, client: nil
      ).and_return(build(:portail_delivery_list))

      described_class.new(membership).call
    end

    it "passes the authorised data stream codes as a filter" do
      expect(Portail::HubAPI::Deliveries).to receive(:list).with(
        siret: "22770001000019", insee_code: "77372", state: "acknowledged",
        data_stream_codes: ["CERTDC"], page: 2, per_page: 25, client: nil
      ).and_return(build(:portail_delivery_list))

      described_class.new(membership).call(state: "acknowledged", page: 2, data_stream_codes: ["CERTDC"])
    end

    # nil et [] se ressemblent et signifient l'inverse : nil vaut « aucun filtre », un tableau
    # vide « aucun accès ». Transmis tel quel, ce dernier ouvrirait tout le périmètre.
    it "applies no filter when the authorised perimeter carries none" do
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(data_stream_codes: []))
        # Seul le filtre est en cause ici ; le hash complet est éprouvé juste au-dessus.
        .and_return(build(:portail_delivery_list))

      described_class.new(membership).call(data_stream_codes: nil)
    end

    # Un périmètre vide ne doit exiger ni appel, ni credentials.
    it "serves a complete empty page without calling the upstream" do
      expect(Portail::HubAPI::Deliveries).not_to receive(:list)

      result = described_class.new(membership).call(data_stream_codes: [])

      expect(result.deliveries).to be_empty
      expect(result.pagination).to have_attributes(current_page: 1, total_pages: 1)
      expect(result.counts_by_state.values).to all(eq(0))
    end

    it "hands the injected client through to the boundary" do
      # Un jeton opaque : ce que le query object en fait est de le transmettre, rien de plus.
      client = double("upstream client")
      expect(Portail::HubAPI::Deliveries).to receive(:list)
        .with(hash_including(client: client))
        # L'injection est le seul objet de cet exemple ; le reste du hash est éprouvé plus haut.
        .and_return(build(:portail_delivery_list))

      described_class.new(membership, client: client).call
    end
  end
end
