# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription::List do
  describe "#portal_data_stream_codes" do
    # Deux abonnements sur un même flux ne le donnent qu'une fois ; un abonnement par l'API ou
    # sans lecture ne compte pas. L'ordre est l'affaire de l'appelant.
    it "projects the distinct data streams read through the portal" do
      list = build(:portail_subscription_list, subscriptions: [
        build(:portail_subscription, data_stream_code: "CERTDC"),
        build(:portail_subscription, id: "sub-2", data_stream_code: "CERTDC"),
        build(:portail_subscription, id: "sub-3", data_stream_code: "AEC"),
        build(:portail_subscription, id: "sub-4", data_stream_code: "DEMO_API", access_mode: "api"),
        build(:portail_subscription, id: "sub-5", data_stream_code: "DEMO_DORMANT", read_package: false)
      ])

      expect(list.portal_data_stream_codes).to contain_exactly("CERTDC", "AEC")
    end

    it "is empty without any subscription" do
      expect(build(:portail_subscription_list, subscriptions: []).portal_data_stream_codes).to eq([])
    end
  end

  describe "#data_stream_names" do
    # Tous les abonnements nomment, quel que soit leur canal : un intitulé ne confère aucun
    # droit. Un flux sans intitulé n'a pas d'entrée, le repli sur le code appartient à l'écran.
    it "projects the name of every named data stream, by code" do
      list = build(:portail_subscription_list, subscriptions: [
        build(:portail_subscription, data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"),
        build(:portail_subscription, id: "sub-2", data_stream_code: "AEC", data_stream_name: "Actes d'état civil", access_mode: "api"),
        build(:portail_subscription, id: "sub-3", data_stream_code: "DEMO", data_stream_name: nil)
      ])

      expect(list.data_stream_names).to eq({"CERTDC" => "Certificat de décès électronique", "AEC" => "Actes d'état civil"})
    end

    it "is empty without any subscription" do
      expect(build(:portail_subscription_list, subscriptions: []).data_stream_names).to eq({})
    end
  end
end
