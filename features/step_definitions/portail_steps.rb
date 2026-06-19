# frozen_string_literal: true

Quand("je visite {string}") do |path|
  get path
end

Alors("la réponse n'est pas une erreur") do
  expect(last_response.status).to be < 400
end
