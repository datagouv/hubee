json.extract! data_stream, :id, :name, :description, :retention_days, :created_at, :updated_at
json.owner_organization do
  json.partial! "api/v1/organizations/organization", organization: data_stream.owner_organization
end
