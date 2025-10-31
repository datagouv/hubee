json.id subscription.uuid
json.extract! subscription, :permission_type, :created_at, :updated_at
json.data_stream_id subscription.data_stream_uuid
json.organization_id subscription.organization_siret
