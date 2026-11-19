# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::AgentSearchForm do
  def errors_of(form)
    form.validate
    form.errors.details
  end

  describe "#valid?" do
    it "accepts an empty search" do
      expect(described_class.new).to be_valid
    end

    it "accepts every criterion" do
      form = described_class.new(siret: "21750056000016", insee_code: "75056", role: "member", search: "alice mar")

      expect(form).to be_valid
    end

    it "refuses a siret that is not made of 14 digits" do
      expect(errors_of(described_class.new(siret: "123"))).to eq(siret: [{error: :invalid, value: "123"}])
    end

    it "refuses an insee code without a siret" do
      expect(errors_of(described_class.new(insee_code: "75056"))).to eq(insee_code: [{error: :requires_siret}])
    end

    it "treats a blank siret as absent" do
      expect(errors_of(described_class.new(siret: "  ", insee_code: "75056"))).to eq(insee_code: [{error: :requires_siret}])
    end

    it "refuses an unknown role" do
      expect(errors_of(described_class.new(role: "owner"))).to eq(role: [{error: :inclusion, value: "owner"}])
    end

    it "accepts both roles" do
      expect(Membership.roles.keys.map { described_class.new(role: it) }).to all(be_valid)
    end

    # Écarter un critère qui n'est pas une chaîne rendrait tout le stock au lieu de la recherche demandée.
    [["alice"], {"a" => "alice"}].each do |value|
      it "refuses every criterion that is not a string (#{value.inspect})" do
        form = described_class.new(siret: value, insee_code: value, role: value, search: value)

        expect(errors_of(form)).to eq(
          siret: [{error: :not_a_string}], insee_code: [{error: :not_a_string}],
          role: [{error: :not_a_string}], search: [{error: :not_a_string}]
        )
      end
    end

    it "accepts a search of 255 characters and refuses a longer one" do
      expect(described_class.new(search: "a" * 255)).to be_valid
      expect(errors_of(described_class.new(search: "a" * 256))).to eq(search: [{error: :too_long, count: 255}])
    end

    it "counts the length of the search once stripped" do
      expect(described_class.new(search: " #{"a" * 255} ")).to be_valid
    end

    it "accepts the bounds of the pagination" do
      expect([
        described_class.new(page: "1", per_page: "1"),
        described_class.new(page: "1000", per_page: "100"),
        described_class.new(page: 3, per_page: 20)
      ]).to all(be_valid)
    end

    # Une page lointaine coûterait un parcours de tout le stock ; au-delà de 1000, la base déborderait.
    pages = {
      "a word" => {value: "abc", error: {error: :not_a_number, value: "abc"}},
      "zero" => {value: "0", error: {error: :greater_than_or_equal_to, value: 0, count: 1}},
      "a negative number" => {value: "-5", error: {error: :greater_than_or_equal_to, value: -5, count: 1}},
      "a decimal" => {value: "1.5", error: {error: :not_an_integer, value: "1.5"}},
      "beyond 1000" => {value: "1001", error: {error: :less_than_or_equal_to, value: 1001, count: 1000}},
      "beyond a bigint" => {value: "1#{"0" * 30}", error: {error: :less_than_or_equal_to, value: 10**30, count: 1000}},
      "a list" => {value: ["2"], error: {error: :not_a_number, value: ["2"]}},
      "an object" => {value: {"a" => "2"}, error: {error: :not_a_number, value: {"a" => "2"}}}
    }
    pages.each do |label, page|
      it "refuses a page that is #{label}" do
        expect(errors_of(described_class.new(page: page[:value]))).to eq(page: [page[:error]])
      end
    end

    per_pages = {
      "a word" => {value: "abc", error: {error: :not_a_number, value: "abc"}},
      "zero" => {value: "0", error: {error: :greater_than_or_equal_to, value: 0, count: 1}},
      "a negative number" => {value: "-5", error: {error: :greater_than_or_equal_to, value: -5, count: 1}},
      "a decimal" => {value: "1.5", error: {error: :not_an_integer, value: "1.5"}},
      "beyond 100" => {value: "101", error: {error: :less_than_or_equal_to, value: 101, count: 100}},
      "a list" => {value: ["2"], error: {error: :not_a_number, value: ["2"]}}
    }
    per_pages.each do |label, per_page|
      it "refuses a per_page that is #{label}" do
        expect(errors_of(described_class.new(per_page: per_page[:value]))).to eq(per_page: [per_page[:error]])
      end
    end
  end

  describe "#pagination" do
    it "defaults to the first page of 50" do
      expect(described_class.new.pagination).to eq(page: 1, limit: 50)
    end

    # Une valeur vide vaut absence, comme pour les critères.
    it "reads a blank value as absent" do
      expect(described_class.new(page: "", per_page: " ").pagination).to eq(page: 1, limit: 50)
    end

    it "gives the received page and size as integers" do
      expect(described_class.new(page: " 3 ", per_page: "20").pagination).to eq(page: 3, limit: 20)
    end
  end

  describe "#criteria" do
    it "strips the criteria and turns blank ones into nil" do
      form = described_class.new(siret: " 21750056000016 ", insee_code: "", role: " ", search: "  alice mar ")

      expect(form.criteria).to eq(siret: "21750056000016", insee_code: nil, role: nil, search: "alice mar")
    end

    it "is all nil for an empty search" do
      expect(described_class.new.criteria).to eq(siret: nil, insee_code: nil, role: nil, search: nil)
    end
  end

  describe "#error_details" do
    it "gives the reasons flat, by parameter" do
      form = described_class.new(insee_code: "75056", role: "owner")
      form.validate

      expect(form.error_details).to eq(insee_code: ["ne s'emploie qu'avec un SIRET"], role: ["n'est pas inclus(e) dans la liste"])
    end

    it "words a criterion that is not a string" do
      form = described_class.new(search: ["alice"])
      form.validate

      expect(form.error_details).to eq(search: ["doit être une chaîne, pas une liste ni un objet"])
    end
  end
end
