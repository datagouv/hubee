json.id data_stream.uuid
json.extract! data_stream, :name, :description, :retention_days, :created_at
json.owner_organization_id data_stream.owner_organization.siret
