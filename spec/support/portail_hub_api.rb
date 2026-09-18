# frozen_string_literal: true

# Décor de la frontière Portail::HubAPI pour les request specs du portail.
module PortailHubAPIStubs
  # `allow` et non `expect` : ce helper est inclus globalement dans les request specs et pose
  # le décor de dizaines d'exemples qui n'atteignent pas tous les abonnements (visiteur
  # redirigé, rattachement sans habilitation). Un exemple qui *vérifie* la lecture arme son
  # propre expect(...).to receive(:list) dans le `it`.
  def stub_organisation_subscriptions(names = {"CERTDC" => "Certificat de décès électronique"})
    list = build(:portail_subscription_list, subscriptions: names.map.with_index do |(code, name), index|
      build(:portail_subscription, id: "sub-#{index}", data_stream_code: code, data_stream_name: name)
    end)
    allow(Portail::HubAPI::Subscriptions).to receive(:list).and_return(list)
  end
end

RSpec.configure do |config|
  config.include PortailHubAPIStubs, type: :request
end
