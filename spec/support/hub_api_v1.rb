# frozen_string_literal: true

# La gem n'étant pas auto-requise, ses bouchons ne le sont pas non plus.
require "hub_api_v1/testing"

RSpec.configure do |config|
  config.include HubApiV1::Testing::Stubs
end
