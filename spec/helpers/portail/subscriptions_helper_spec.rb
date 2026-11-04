# frozen_string_literal: true

require "rails_helper"

# Les champs d'un abonnement à l'écran, avec leur repli.
RSpec.describe Portail::SubscriptionsHelper, type: :helper do
  # Un libellé court qui se lit d'un coup d'œil, la précision dessous quand elle apprend quelque chose.
  frequencies = {
    "per_delivery" => {label: "À chaque télédossier", hint: "Un courriel dès qu'un télédossier arrive"},
    "daily" => {label: "Une fois par jour", hint: "Un récapitulatif des télédossiers en attente, le matin"},
    "twice_daily" => {label: "Deux fois par jour",
                      hint: "Un récapitulatif des télédossiers en attente, le matin et à midi"},
    "none" => {label: "Aucun courriel", hint: nil},
    "unknown" => {label: "Non renseignée", hint: nil}
  }

  describe "#subscription_email_frequency" do
    it "names each frequency shortly" do
      frequencies.each do |frequency, texts|
        configuration = build(:portail_delivery_email_configuration, frequency: frequency)

        expect(helper.subscription_email_frequency(configuration)).to eq(texts[:label])
      end
    end
  end

  describe "#subscription_email_frequency_hint" do
    it "explains what each frequency sends, nothing when the label says it all" do
      frequencies.each do |frequency, texts|
        configuration = build(:portail_delivery_email_configuration, frequency: frequency)

        expect(helper.subscription_email_frequency_hint(configuration)).to eq(texts[:hint]), frequency
      end
    end
  end

  describe "#subscription_access_mode" do
    # La liste garde le tiret ; le détail, qui a la place de le dire, passe son propre repli.
    it "names the access mode, falls back to the given text when unset" do
      expect(helper.subscription_access_mode(build(:portail_subscription, access_mode: "api"))).to eq("API")
      expect(helper.subscription_access_mode(build(:portail_subscription, access_mode: nil))).to eq("—")
      expect(helper.subscription_access_mode(build(:portail_subscription, access_mode: nil), missing: "Non renseignée"))
        .to eq("Non renseignée")
    end
  end
end
