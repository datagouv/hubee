# frozen_string_literal: true

RSpec.shared_examples "a boolean filter scope" do |scope_name, attribute_name|
  let!(:sub_read) { create(:subscription, :read_only) }
  let!(:sub_write) { create(:subscription, :write_only) }
  let!(:sub_read_write) { create(:subscription, :read_write) }

  let(:true_results) do
    [sub_read, sub_write, sub_read_write].select { |s| s.public_send(attribute_name) }
  end

  let(:false_results) do
    [sub_read, sub_write, sub_read_write].reject { |s| s.public_send(attribute_name) }
  end

  it "filters by #{attribute_name} true" do
    expect(Subscription.public_send(scope_name, true)).to contain_exactly(*true_results)
  end

  it "filters by #{attribute_name} false" do
    expect(Subscription.public_send(scope_name, false)).to contain_exactly(*false_results)
  end

  it "filters by #{attribute_name} 'true' string" do
    expect(Subscription.public_send(scope_name, "true")).to contain_exactly(*true_results)
  end

  it "filters by #{attribute_name} 'false' string" do
    expect(Subscription.public_send(scope_name, "false")).to contain_exactly(*false_results)
  end

  it "returns all when value is nil" do
    expect(Subscription.public_send(scope_name, nil)).to contain_exactly(sub_read, sub_write, sub_read_write)
  end
end
