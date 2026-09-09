# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::Criteria do
  describe ".from_params" do
    it "reads every criterion from the query string" do
      criteria = described_class.from_params(ActionController::Parameters.new(
        statut: "done", flux: ["CERTDC", "AEC"], numero: "ID22026", du: "2026-08-01", au: "2026-08-31",
        tri: "updated_at", ordre: "asc", page: "2"
      ))

      expect(criteria).to eq(described_class.new(
        state: "done", data_stream_codes: ["CERTDC", "AEC"], number: "ID22026",
        transmitted_from: "2026-08-01", transmitted_to: "2026-08-31",
        sort: "updated_at", direction: "asc"
      ))
    end

    # `?du=` vide est ce qu'un formulaire soumet avec un champ laissé vide ; aucune case cochée
    # ne soumet rien du tout.
    it "falls back on the defaults when a criterion is absent or blank" do
      criteria = described_class.from_params(ActionController::Parameters.new(du: ""))

      expect(criteria).to eq(described_class.new(
        state: "transmitted", data_stream_codes: [], number: nil, transmitted_from: nil, transmitted_to: nil,
        sort: "transmitted_at", direction: "desc"
      ))
    end

    # L'amont ne retire pas les blancs d'un numéro collé ; des blancs seuls ne sont pas une recherche.
    it "reads the number without its surrounding blanks, none at all as no number" do
      expect(described_class.from_params({numero: "  ID22026 "}).number).to eq("ID22026")
      expect(described_class.from_params({numero: "   "}).number).to be_nil
    end

    # Un seul flux dans l'URL s'écrit aussi sans crochets ; les blancs et les doublons tombent.
    it "reads the data streams as a list, a scalar included, blanks and repeats dropped" do
      expect(described_class.from_params({flux: "CERTDC"}).data_stream_codes).to eq(["CERTDC"])
      expect(described_class.from_params({flux: ["CERTDC", "", "CERTDC", "AEC"]}).data_stream_codes)
        .to eq(["CERTDC", "AEC"])
    end

    # Aucune validation : l'amont tranche, et son refus est affiché plutôt que corrigé en douce.
    it "keeps a non-scalar value as a string for the upstream to refuse" do
      criteria = described_class.from_params(ActionController::Parameters.new(statut: ["done"]))

      expect(criteria.state).to eq('["done"]')
    end
  end

  describe "#link_params" do
    # Les liens de la page repartent de ces params : les défauts n'y figurent pas, sinon chaque
    # lien du menu d'états porterait un tri implicite.
    it "serialises the criteria that differ from the defaults, the state always" do
      criteria = described_class.new(
        state: "done", data_stream_codes: ["CERTDC", "AEC"], number: "ID22026", transmitted_from: "2026-08-01",
        transmitted_to: nil, sort: "transmitted_at", direction: "asc"
      )

      expect(criteria.link_params).to eq(
        statut: "done", flux: ["CERTDC", "AEC"], numero: "ID22026", du: "2026-08-01", ordre: "asc"
      )
    end

    it "serialises the default criteria as the state alone" do
      expect(described_class.from_params({}).link_params).to eq(statut: "transmitted")
    end
  end

  describe "#filtered?" do
    it "is true as soon as a filter is set, the number included, whatever the sort" do
      expect(described_class.from_params({flux: "CERTDC"})).to be_filtered
      expect(described_class.from_params({numero: "ID22026"})).to be_filtered
      expect(described_class.from_params({au: "2026-08-31"})).to be_filtered
      expect(described_class.from_params({tri: "updated_at"})).not_to be_filtered
    end
  end
end
