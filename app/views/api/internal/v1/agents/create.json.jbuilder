# L'état enregistré, pas l'état demandé : pour un agent connu ailleurs, l'identité retenue.
agent = @membership.agent
json.extract! agent, :id, :email, :first_name, :last_name, :civility
json.membership do
  json.partial! "api/internal/v1/agents/membership", membership: @membership
end
