# frozen_string_literal: true

json.subscriptions @subscriptions do |subscription|
  json.partial! "api/v1/subscriptions/subscription", subscription: subscription
end

json.source @data_package.subscriptions_source
json.delivery_criteria @data_package.delivery_criteria
