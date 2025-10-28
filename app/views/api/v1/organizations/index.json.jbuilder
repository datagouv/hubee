json.array! @organizations do |organization|
  json.extract! organization, :name, :siret, :created_at
end
