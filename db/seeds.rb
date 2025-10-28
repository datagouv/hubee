# Seeds pour développement
# Usage : bin/rails db:seed

puts "🌱 Seeding database..."

# Nettoyer les données existantes (développement uniquement)
if Rails.env.development?
  puts "  🧹 Cleaning existing data..."
  DataStream.destroy_all
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

# DataStreams de test
dinum = Organization.find_by!(siret: "13002526500013")
anssi = Organization.find_by!(siret: "13002802100010")
dila = Organization.find_by!(siret: "13001727000014")
cnam = Organization.find_by!(siret: "18075501200017")
pole_emploi = Organization.find_by!(siret: "13002039200011")
caf_paris = Organization.find_by!(siret: "77566988100032")
prefecture_paris = Organization.find_by!(siret: "17750005600019")
mairie_lyon = Organization.find_by!(siret: "26690123100013")

data_streams_data = [
  # DINUM
  {
    name: "CertDC",
    description: "Certificats de décès - Flux principal entre communes et organismes publics",
    owner_organization: dinum,
    retention_days: 365
  },
  {
    name: "JustificatifDomicile",
    description: "Justificatifs de domicile pour démarches administratives",
    owner_organization: dinum,
    retention_days: 180
  },
  {
    name: "CertificatsScolarite",
    description: "Certificats de scolarité pour aides et allocations",
    owner_organization: dinum,
    retention_days: 730
  },
  # ANSSI
  {
    name: "RapportsSecurite",
    description: "Rapports d'audit de sécurité SecNumCloud",
    owner_organization: anssi,
    retention_days: 1825
  },
  {
    name: "AnalysesVulnerabilites",
    description: "Analyses de vulnérabilités des systèmes critiques",
    owner_organization: anssi,
    retention_days: 1095
  },
  # DILA
  {
    name: "JournalOfficiel",
    description: "Textes et annonces du Journal Officiel",
    owner_organization: dila,
    retention_days: 3650
  },
  # CNAM
  {
    name: "AttestationSecuriteSociale",
    description: "Attestations de droits à l'assurance maladie",
    owner_organization: cnam,
    retention_days: 365
  },
  {
    name: "FeuillesSoins",
    description: "Feuilles de soins électroniques",
    owner_organization: cnam,
    retention_days: 730
  },
  # Pôle Emploi
  {
    name: "AttestationsInscription",
    description: "Attestations d'inscription comme demandeur d'emploi",
    owner_organization: pole_emploi,
    retention_days: 365
  },
  {
    name: "ContratsTravail",
    description: "Contrats de travail pour vérification employeur",
    owner_organization: pole_emploi,
    retention_days: 1095
  },
  # CAF Paris
  {
    name: "AttestationsQuotientFamilial",
    description: "Attestations de quotient familial pour services municipaux",
    owner_organization: caf_paris,
    retention_days: 180
  },
  {
    name: "NotificationsPrestations",
    description: "Notifications de droits aux prestations familiales",
    owner_organization: caf_paris,
    retention_days: 365
  },
  # Préfecture Paris
  {
    name: "TitresSejourElectroniques",
    description: "Titres de séjour électroniques",
    owner_organization: prefecture_paris,
    retention_days: 1825
  },
  {
    name: "CartesIdentite",
    description: "Demandes de cartes nationales d'identité",
    owner_organization: prefecture_paris,
    retention_days: 365
  },
  # Mairie Lyon
  {
    name: "ActesEtatCivil",
    description: "Actes d'état civil dématérialisés",
    owner_organization: mairie_lyon,
    retention_days: 730
  },
  {
    name: "PermisConstructionElectroniques",
    description: "Permis de construire en format numérique",
    owner_organization: mairie_lyon,
    retention_days: 3650
  }
]

puts "  📡 Creating #{data_streams_data.size} data streams..."

data_streams_data.each do |stream_data|
  DataStream.find_or_create_by!(
    name: stream_data[:name],
    owner_organization: stream_data[:owner_organization]
  ) do |stream|
    stream.description = stream_data[:description]
    stream.retention_days = stream_data[:retention_days]
  end
end

puts "  ✅ Created #{DataStream.count} data streams"
puts "🎉 Seeding completed!"
