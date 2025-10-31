json.id data_stream.uuid
json.extract! data_stream, :name, :description, :retention_days, :created_at, :updated_at
json.owner_organization_siret data_stream.owner_organization_siret
