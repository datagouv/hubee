# L'état enregistré, pas l'état demandé : pour un agent connu ailleurs, l'identité retenue.
agent = @membership.agent
json.extract! agent, :id, :email, :first_name, :last_name, :civility
json.membership do
  json.extract! @membership.organization_link, :siret, :insee_code
  json.extract! @membership, :role, :job_title, :phone_number, :mobile_phone_number, :data_stream_codes
end
