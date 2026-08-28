# Seeds pour développement
# Usage : bin/rails db:seed

puts "🌱 Seeding database..."

# Nettoyer les données existantes (développement uniquement)
if Rails.env.development?
  puts "  🧹 Cleaning existing data..."
  DataPackage.destroy_all
  Subscription.destroy_all
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

# Subscriptions de test (permissions read/write)
cert_dc = DataStream.find_by!(name: "CertDC")
justif_domicile = DataStream.find_by!(name: "JustificatifDomicile")
attestations_ss = DataStream.find_by!(name: "AttestationSecuriteSociale")
attestations_inscription = DataStream.find_by!(name: "AttestationsInscription")
attestations_qf = DataStream.find_by!(name: "AttestationsQuotientFamilial")
actes_etat_civil = DataStream.find_by!(name: "ActesEtatCivil")

subscriptions_data = [
  # CertDC (DINUM) - Accessible en lecture par plusieurs organismes
  {data_stream: cert_dc, organization: cnam, can_read: true, can_write: false},
  {data_stream: cert_dc, organization: caf_paris, can_read: true, can_write: false},
  {data_stream: cert_dc, organization: pole_emploi, can_read: true, can_write: false},
  {data_stream: cert_dc, organization: mairie_lyon, can_read: true, can_write: true},
  {data_stream: cert_dc, organization: prefecture_paris, can_read: true, can_write: false},

  # JustificatifDomicile (DINUM) - Partagé largement
  {data_stream: justif_domicile, organization: caf_paris, can_read: true, can_write: false},
  {data_stream: justif_domicile, organization: prefecture_paris, can_read: true, can_write: false},
  {data_stream: justif_domicile, organization: mairie_lyon, can_read: true, can_write: true},

  # AttestationSecuriteSociale (CNAM) - Accès lecture pour organismes sociaux
  {data_stream: attestations_ss, organization: caf_paris, can_read: true, can_write: false},
  {data_stream: attestations_ss, organization: pole_emploi, can_read: true, can_write: false},
  {data_stream: attestations_ss, organization: mairie_lyon, can_read: true, can_write: false},

  # AttestationsInscription (Pôle Emploi) - Accès pour organismes de prestations
  {data_stream: attestations_inscription, organization: caf_paris, can_read: true, can_write: false},
  {data_stream: attestations_inscription, organization: cnam, can_read: true, can_write: false},

  # AttestationsQuotientFamilial (CAF Paris) - Accès communes
  {data_stream: attestations_qf, organization: mairie_lyon, can_read: true, can_write: false},
  {data_stream: attestations_qf, organization: dinum, can_read: true, can_write: false},

  # ActesEtatCivil (Mairie Lyon) - Accès administrations centrales
  {data_stream: actes_etat_civil, organization: dinum, can_read: true, can_write: false},
  {data_stream: actes_etat_civil, organization: prefecture_paris, can_read: true, can_write: false},
  {data_stream: actes_etat_civil, organization: cnam, can_read: true, can_write: false},

  # Exemples permissions write seule (producteurs délégués)
  {data_stream: cert_dc, organization: Organization.find_by!(siret: "20006254900011"), can_read: false, can_write: true}
]

puts "  🔐 Creating #{subscriptions_data.size} subscriptions..."

subscriptions_data.each do |sub_data|
  subscription = Subscription.find_or_initialize_by(
    data_stream: sub_data[:data_stream],
    organization: sub_data[:organization]
  )
  subscription.update!(
    can_read: sub_data[:can_read],
    can_write: sub_data[:can_write]
  )
end

puts "  ✅ Created #{Subscription.count} subscriptions"

# DataPackages de test (paquets envoyés/en cours)
data_packages_data = [
  # CertDC - Packages draft
  {
    data_stream: cert_dc,
    sender_organization: mairie_lyon,
    title: "CertDC-20250101-093000-A1B2",
    state: :draft
  },
  {
    data_stream: cert_dc,
    sender_organization: prefecture_paris,
    title: "CertDC-20250115-141500-C3D4",
    state: :draft
  },
  # CertDC - Packages sent
  {
    data_stream: cert_dc,
    sender_organization: mairie_lyon,
    title: "CertDC-20250201-100000-E5F6",
    state: :transmitted,
    sent_at: 1.day.ago
  },
  {
    data_stream: cert_dc,
    sender_organization: prefecture_paris,
    title: "CertDC-20250131-153000-G7H8",
    state: :transmitted,
    sent_at: 2.days.ago
  },
  {
    data_stream: cert_dc,
    sender_organization: mairie_lyon,
    title: "CertDC-20250128-083000-I9J0",
    state: :transmitted,
    sent_at: 5.days.ago
  },
  # CertDC - Packages acknowledged
  {
    data_stream: cert_dc,
    sender_organization: prefecture_paris,
    title: "CertDC-20250115-120000-K1L2",
    state: :acknowledged,
    sent_at: 18.days.ago,
    acknowledged_at: 17.days.ago
  },
  {
    data_stream: cert_dc,
    sender_organization: mairie_lyon,
    title: "CertDC-20250110-094500-M3N4",
    state: :acknowledged,
    sent_at: 23.days.ago,
    acknowledged_at: 22.days.ago
  },
  # AttestationSecuriteSociale - Packages variés
  {
    data_stream: attestations_ss,
    sender_organization: cnam,
    title: "AttestationSecuriteSociale-20250201-140000-P5Q6",
    state: :draft
  },
  {
    data_stream: attestations_ss,
    sender_organization: cnam,
    title: "AttestationSecuriteSociale-20250131-110000-R7S8",
    state: :transmitted,
    sent_at: 2.days.ago
  },
  {
    data_stream: attestations_ss,
    sender_organization: cnam,
    title: "AttestationSecuriteSociale-20250125-083000-T9U0",
    state: :acknowledged,
    sent_at: 8.days.ago,
    acknowledged_at: 7.days.ago
  },
  # ActesEtatCivil - Packages
  {
    data_stream: actes_etat_civil,
    sender_organization: mairie_lyon,
    title: "ActesEtatCivil-20250201-154500-V1W2",
    state: :draft
  },
  {
    data_stream: actes_etat_civil,
    sender_organization: mairie_lyon,
    title: "ActesEtatCivil-20250130-101500-X3Y4",
    state: :transmitted,
    sent_at: 3.days.ago
  }
]

puts "  📦 Creating #{data_packages_data.size} data packages..."

data_packages_data.each do |pkg_data|
  DataPackage.find_or_create_by!(
    title: pkg_data[:title]
  ) do |pkg|
    pkg.data_stream = pkg_data[:data_stream]
    pkg.sender_organization = pkg_data[:sender_organization]
    pkg.state = pkg_data[:state]
    pkg.sent_at = pkg_data[:sent_at] if pkg_data[:sent_at]
    pkg.acknowledged_at = pkg_data[:acknowledged_at] if pkg_data[:acknowledged_at]
  end
end

puts "  ✅ Created #{DataPackage.count} data packages"

# Agents du portail V2, alignés sur les comptes réels des FI de test ProConnect :
# userN@yopmail.com (ProConnect Identité, org DINUM), identités libres de FIA1
# (@test.proconnect.gouv.fr, SIRET saisissable), et le compte du FI ANCT.
# Idempotent et non destructif : identités scellées (provider_sub) et traces
# (AccessDecision) préservées ; seul le rôle est réaligné.
puts "  👤 Creating portal agents..."

# Comme au référentiel V1 : chaque organisation porte son propre code INSEE, sous la
# forme majoritaire observée (numérique, 5 chiffres).
dinum_link = OrganizationLink.find_or_create_by!(siret: "13002526500013", insee_code: "00001")
lyon_link = OrganizationLink.find_or_create_by!(siret: "26690123100013", insee_code: "00002")
sardine_link = OrganizationLink.find_or_create_by!(siret: "84087593400027", insee_code: "00003")

# Aligné sur SENSITIVE_PROCESS_CODES pour que l'habilitation semée déclenche bien
# l'élévation ; repli documenté si la liste est vide.
sensitive_code = Portail::SensitiveProcesses::CODES.first || "DEMO_SENSIBLE"

portal_agents = [
  # [email, prénom, nom, lien, rôle, habilitation sensible]
  ["user@yopmail.com", "Camille", "Ordinaire", dinum_link, "member", false],
  ["user1@yopmail.com", "Alex", "Admin", dinum_link, "local_administrator", false],
  ["user2@yopmail.com", "Dominique", "Habilite", dinum_link, "member", true],
  ["user3@yopmail.com", "Sacha", "Ailleurs", lyon_link, "member", false],
  ["agent@test.proconnect.gouv.fr", "Camille", "Fia", dinum_link, "member", false],
  ["admin@test.proconnect.gouv.fr", "Alex", "Fia", dinum_link, "local_administrator", false],
  ["sensible@test.proconnect.gouv.fr", "Dominique", "Fia", dinum_link, "member", true],
  ["bastien.ogier@sardinepq.fr", "Bastien", "Ogier", sardine_link, "local_administrator", false]
]

portal_agents.each do |email, first_name, last_name, link, role, sensitive|
  agent = Agent.find_or_create_by!(email:) do |a|
    a.first_name = first_name
    a.last_name = last_name
  end
  # update! séparé : le bloc de find_or_create_by! ne tourne pas sur un existant.
  membership = Membership.find_or_create_by!(agent:, organization_link: link)
  membership.update!(role:)
  ProcessAccess.find_or_create_by!(membership:, process_code: sensitive_code) if sensitive
end

# Le socle de développement local ne sert de démarches que pour cette organisation et ce
# flux. Une identité libre de FIA1 permet de saisir le SIRET à la connexion : c'est ce qui
# rend ce rattachement atteignable en navigateur, sans rien changer au socle. Membre plutôt
# qu'administrateur local, pour que le filtrage par habilitation soit réellement traversé.
# Sans ce rattachement, l'écran reste vide sans que rien ne l'explique.
# Le code INSEE est obligatoire depuis que le lien porte le couple : sans lui, le semis
# entier échoue. Valeur alignée sur celle que les factories de la gem associent à ce SIRET,
# soit ce que le socle sert — c'est elle que la gem transmet en `code_insee`.
socle_link = OrganizationLink.find_or_create_by!(siret: "22770001000019", insee_code: "77372")
socle_agent = Agent.find_or_create_by!(email: "socle@test.proconnect.gouv.fr") do |a|
  a.first_name = "Camille"
  a.last_name = "Socle"
end
socle_membership = Membership.find_or_create_by!(agent: socle_agent, organization_link: socle_link)
socle_membership.update!(role: "member")
ProcessAccess.find_or_create_by!(membership: socle_membership, process_code: "CERTDC")

puts "  ✅ Created #{Agent.count} agents"
if Portail::SensitiveProcesses::CODES.empty?
  puts "  ⚠️  SENSITIVE_PROCESS_CODES vide : l'habilitation #{sensitive_code} ne déclenchera pas d'élévation"
end

puts ""
puts "📊 Summary:"
puts "  - Organizations: #{Organization.count}"
puts "  - Data Streams: #{DataStream.count}"
puts "  - Subscriptions: #{Subscription.count}"
puts "  - Data Packages: #{DataPackage.count}"
puts "  - Agents: #{Agent.count} (#{Membership.count} memberships)"
puts ""
puts "🎉 Seeding completed!"
