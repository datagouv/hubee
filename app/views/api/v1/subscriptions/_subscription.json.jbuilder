json.extract! subscription, :id, :can_read, :can_write, :data_stream_id, :created_at, :updated_at
json.organization do
  json.partial! "api/v1/organizations/organization", organization: subscription.organization
end
