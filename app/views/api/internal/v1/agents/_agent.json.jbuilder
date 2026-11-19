# locals: (agent:, json:)

json.extract! agent, :id, :email, :first_name, :last_name, :civility
# Si l'agent s'est déjà connecté ; l'identifiant du fournisseur d'identité ne sort jamais.
json.has_signed_in agent.provider_sub.present?
json.created_at agent.created_at
# Triés en mémoire : les rattachements sont préchargés, un `order` referait une requête par agent. L'identifiant
# départage deux rattachements créés au même instant.
json.memberships agent.memberships.sort_by { [it.created_at, it.id] } do |membership|
  json.partial! "api/internal/v1/agents/membership", membership:
end
