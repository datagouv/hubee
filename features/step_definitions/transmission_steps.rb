# frozen_string_literal: true

Given("an organization {string} with SIRET {string}") do |name, siret|
  @organizations ||= {}
  @organizations[name] = create(:organization, name: name, siret: siret)
end

Given("a data stream {string} owned by {string}") do |stream_name, org_name|
  @data_streams ||= {}
  owner = @organizations[org_name]
  @data_streams[stream_name] = create(:data_stream, name: stream_name, owner_organization: owner)
end

Given("{string} is subscribed to {string} with read permission") do |org_name, stream_name|
  organization = @organizations[org_name]
  data_stream = @data_streams[stream_name]
  create(:subscription, organization: organization, data_stream: data_stream, can_read: true)
end

When("I create a data package for {string} from {string} targeting SIRET {string}") do |stream_name, org_name, siret|
  data_stream = @data_streams[stream_name]
  sender = @organizations[org_name]
  @data_package = create(
    :data_package,
    data_stream: data_stream,
    sender_organization: sender,
    delivery_criteria: {"siret" => [siret]}
  )
end

When("I create a data package for {string} from {string} targeting SIRETs:") do |stream_name, org_name, table|
  data_stream = @data_streams[stream_name]
  sender = @organizations[org_name]
  sirets = table.hashes.map { |row| row["siret"] }
  @data_package = create(
    :data_package,
    data_stream: data_stream,
    sender_organization: sender,
    delivery_criteria: {"siret" => sirets}
  )
end

Then("the data package is created in {string} state") do |expected_state|
  expect(@data_package.state).to eq(expected_state)
end

When("I transmit the data package") do
  @data_package.define_singleton_method(:has_completed_attachments?) { true }
  @transmission_result = DataPackages::Transmit.call(data_package: @data_package)
end

Then("the transmission succeeds") do
  expect(@transmission_result).to be_success
end

Then("the transmission fails with {string} error") do |error_type|
  expect(@transmission_result).to be_failure
  expect(@transmission_result.error).to eq(error_type.tr(" ", "_").to_sym)
end

Then("the data package state is {string}") do |expected_state|
  @data_package.reload
  expect(@data_package.state).to eq(expected_state)
end

Then("a notification is created for {string}") do |org_name|
  organization = @organizations[org_name]
  subscription = Subscription.find_by(organization: organization)
  notification = @data_package.notifications.find_by(subscription: subscription)
  expect(notification).to be_present
end

Then("the notification is not yet acknowledged") do
  notification = @data_package.notifications.first
  expect(notification.acknowledged_at).to be_nil
end

Then("{int} notifications are created") do |count|
  expect(@data_package.notifications.count).to eq(count)
end

Then("no notifications are created") do
  expect(@data_package.notifications.count).to eq(0)
end
