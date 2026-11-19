# locals: (membership:, json:)

json.id membership.id
json.extract! membership.organization_link, :siret, :insee_code
json.extract! membership, :role, :job_title, :phone_number, :mobile_phone_number, :data_stream_codes, :last_signed_in_at
