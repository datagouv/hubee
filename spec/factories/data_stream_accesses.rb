FactoryBot.define do
  factory :data_stream_access do
    membership
    sequence(:data_stream_code) { |n| "FLUX-#{n}" }
  end
end
