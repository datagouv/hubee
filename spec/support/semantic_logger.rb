# frozen_string_literal: true

# Capture des journaux au niveau du processeur de semantic_logger, sans intercepter les
# méthodes du logger : un `info` ajouté ailleurs dans la requête ne casse aucun exemple.
require "semantic_logger/test/rspec"

RSpec.configure do |config|
  config.include SemanticLogger::Test::RSpec
end
