FactoryBot.define do
  factory :organization_link do
    # Base volontairement fictive : le SIRET des seeds (13002526500013) a déjà provoqué
    # une collision avec des specs de l'API.
    sequence(:siret) { |n| format("%014d", 99999999900000 + n) }
    # Séquencé pour la même raison que le SIRET : l'index unique porte sur le couple.
    sequence(:branch_code) { |n| format("%03d", n) }
  end
end
