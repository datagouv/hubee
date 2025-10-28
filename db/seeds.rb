# Seeds pour développement
# Usage : bin/rails db:seed

puts "🌱 Seeding database..."

# Nettoyer les données existantes (développement uniquement)
if Rails.env.development?
  puts "  🧹 Cleaning existing data..."
  Organization.destroy_all
end

# Organizations de test (administrations françaises réelles avec SIRET fictifs)
organizations_data = [
  {name: "Direction Interministérielle du Numérique (DINUM)", siret: "13002526500013"},
  {name: "Agence Nationale de la Sécurité des Systèmes d'Information (ANSSI)", siret: "13002802100010"},
  {name: "Direction de l'Information Légale et Administrative (DILA)", siret: "13001727000014"},
  {name: "Caisse Nationale d'Assurance Maladie (CNAM)", siret: "18075501200017"},
  {name: "Pôle Emploi", siret: "13002039200011"},
  {name: "Caisse d'Allocations Familiales de Paris", siret: "77566988100032"},
  {name: "Préfecture de Police de Paris", siret: "17750005600019"},
  {name: "Mairie de Lyon", siret: "26690123100013"},
  {name: "Métropole de Marseille", siret: "20006254900011"},
  {name: "Région Île-de-France", siret: "23750001600016"}
]

puts "  📊 Creating #{organizations_data.size} organizations..."

organizations_data.each do |org_data|
  Organization.find_or_create_by!(siret: org_data[:siret]) do |org|
    org.name = org_data[:name]
  end
end

puts "  ✅ Created #{Organization.count} organizations"
puts "🎉 Seeding completed!"
