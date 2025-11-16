# frozen_string_literal: true

RSpec.shared_examples "a paginated endpoint" do
  it "returns pagination headers" do
    expect(response.headers["X-Page"]).to be_present
    expect(response.headers["X-Per-Page"]).to eq(Pagy.options[:limit].to_s)
    expect(response.headers["X-Total"]).to be_present
    expect(response.headers["X-Total-Pages"]).to be_present
  end
end

RSpec.shared_examples "a paginated endpoint respecting page size" do
  context "with many records" do
    let(:total_records) { 60 }
    let(:factory_name) do
      self.class.top_level_description.to_s.split("::").last.singularize.underscore.to_sym
    end
    let(:factory_params) { defined?(pagination_factory_params) ? pagination_factory_params : {} }

    before do
      total_records.times { create(factory_name, **factory_params) }
      make_request
    end

    it "respects default page size from Pagy config" do
      expect(json.size).to eq(Pagy.options[:limit])
    end

    it_behaves_like "a paginated endpoint"
  end
end
