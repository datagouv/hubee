# frozen_string_literal: true

require "rails_helper"

# Modifier ou retirer un rattachement relève de la gestion de l'agent : même droit que sa modification.
RSpec.describe API::Internal::V1::MembershipPolicy do
  %i[update? destroy?].each do |action|
    describe "##{action}" do
      let(:client) { create(:oauth_application) }

      it "allows #{action} to a client holding internal:agents:update" do
        create(:oauth_application_right, oauth_application: client, right: "internal:agents:update")

        expect(described_class.new(client, :membership).public_send(action)).to be(true)
      end

      it "refuses #{action} to a client holding only the other rights" do
        %w[internal:agents:read internal:agents:destroy internal:agents:create].each do |right|
          create(:oauth_application_right, oauth_application: client, right:)
        end

        expect(described_class.new(client, :membership).public_send(action)).to be(false)
      end
    end
  end
end
