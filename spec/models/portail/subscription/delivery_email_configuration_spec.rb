# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription::DeliveryEmailConfiguration do
  describe "#sends_emails?" do
    # Une fréquence inconnue n'est pas une absence d'envoi : rien ne permet de l'affirmer.
    frequencies = {
      "per delivery" => {frequency: "per_delivery", sends: true},
      "daily" => {frequency: "daily", sends: true},
      "twice daily" => {frequency: "twice_daily", sends: true},
      "unknown" => {frequency: "unknown", sends: true},
      "none" => {frequency: "none", sends: false}
    }

    it "sends emails unless the frequency is none" do
      frequencies.each_value do |state|
        configuration = described_class.new(frequency: state[:frequency], recipients: ["a@commune.fr"])

        expect(configuration.sends_emails?).to be(state[:sends]), state[:frequency]
      end
    end
  end
end
