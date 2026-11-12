# frozen_string_literal: true

# Décor de la frontière Portail::HubAPI pour les request specs du portail.
module PortailHubAPIStubs
  # `allow` et non `expect` : ce helper est inclus globalement dans les request specs et pose
  # le décor de dizaines d'exemples qui n'atteignent pas tous les abonnements (visiteur
  # redirigé, rattachement sans habilitation). Un exemple qui *vérifie* la lecture arme son
  # propre expect(...).to receive(:list) dans le `it`. Les deux flux des habilitations courantes
  # des exemples, reçus par le portail : AEC sans intitulé, le repli sur le code est le décor commun.
  def stub_organisation_subscriptions(names = {"CERTDC" => "Certificat de décès électronique", "AEC" => nil})
    list = build(:portail_subscription_list, subscriptions: names.map.with_index do |(code, name), index|
      build(:portail_subscription, id: "sub-#{index}", data_stream_code: code, data_stream_name: name)
    end)
    allow(Portail::HubAPI::Subscriptions).to receive(:list).and_return(list)
  end

  # Un abonnement par flux, chacun dans son mode d'accès, pour l'organisation de l'agent connecté.
  # Au moins une fois : le filtre de la liste et la policy les lisent chacun, et le cache est nul
  # en test.
  def expect_organisation_subscriptions(access_modes)
    expect(Portail::HubAPI::Subscriptions).to receive(:list).at_least(:once).and_return(
      build(:portail_subscription_list, subscriptions: access_modes.map.with_index do |(code, access_mode), index|
        build(:portail_subscription, id: "sub-#{index}", data_stream_code: code, access_mode:)
      end)
    )
  end

  # Même raison : le détail lit le flux, et la plupart des exemples ne s'intéressent pas à ce
  # qu'il autorise. Permissif par défaut, comme la factory.
  def stub_data_stream(data_stream = build(:portail_data_stream))
    allow(Portail::HubAPI::DataStreams).to receive(:find).and_return(data_stream)
  end
end

RSpec.configure do |config|
  config.include PortailHubAPIStubs, type: :request
end
