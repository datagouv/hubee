json.extract! agent, :id, :email, :civility, :first_name, :last_name, :created_at
json.memberships memberships do |membership|
  json.siret membership.organization_link.siret
  json.insee_code membership.organization_link.insee_code
  json.extract! membership, :role, :job_title, :phone_number
end
