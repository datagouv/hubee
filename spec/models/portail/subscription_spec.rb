# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription do
  describe "#readable_via_portal?" do
    # Les deux conditions, éprouvées séparément : l'une sans l'autre ne suffit pas.
    it "is true for a reading subscription served through the portal only" do
      expect(build(:portail_subscription)).to be_readable_via_portal
      expect(build(:portail_subscription, read_package: false)).not_to be_readable_via_portal
      expect(build(:portail_subscription, access_mode: "api")).not_to be_readable_via_portal
    end
  end

  describe "#data_stream_display_name" do
    it "is the data stream name, the code standing in for a missing one" do
      expect(build(:portail_subscription, data_stream_code: "AEC", data_stream_name: "État civil").data_stream_display_name)
        .to eq("État civil")
      expect(build(:portail_subscription, data_stream_code: "AEC").data_stream_display_name).to eq("AEC")
    end
  end

  describe "#api_access?" do
    # Un canal non renseigné n'est pas l'API : rien n'y montrerait un éditeur.
    it "is true for the API access mode only" do
      expect(build(:portail_subscription, access_mode: "api")).to be_api_access
      expect(build(:portail_subscription, access_mode: "portal")).not_to be_api_access
      expect(build(:portail_subscription, access_mode: nil)).not_to be_api_access
    end
  end
end
