# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription::List do
  describe "#portal_data_stream_codes" do
    # Deux abonnements sur un même flux ne le donnent qu'une fois ; un abonnement par l'API ou
    # sans lecture ne compte pas ; l'ordre est celui des codes, pas celui de l'amont.
    it "projects the distinct data streams read through the portal, sorted" do
      list = build(:portail_subscription_list, subscriptions: [
        build(:portail_subscription, data_stream_code: "CERTDC"),
        build(:portail_subscription, id: "sub-2", data_stream_code: "CERTDC"),
        build(:portail_subscription, id: "sub-3", data_stream_code: "AEC"),
        build(:portail_subscription, id: "sub-4", data_stream_code: "DEMO_API", access_mode: "api"),
        build(:portail_subscription, id: "sub-5", data_stream_code: "DEMO_DORMANT", read_package: false)
      ])

      expect(list.portal_data_stream_codes).to eq(%w[AEC CERTDC])
    end

    it "is empty without any subscription" do
      expect(build(:portail_subscription_list, subscriptions: []).portal_data_stream_codes).to eq([])
    end
  end

  # La liste se parcourt comme ses abonnements : la frontière et ses specs n'ont pas à la déballer.
  it "enumerates its subscriptions" do
    subscription = build(:portail_subscription)

    expect(build(:portail_subscription_list, subscriptions: [subscription]).to_a).to eq([subscription])
  end
end
