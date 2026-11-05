# frozen_string_literal: true

require "rails_helper"

# Le sujet est le client de l'API, et le droit se lit sur lui à chaque appel : il n'est pas dans le jeton.
RSpec.describe API::Internal::V1::AgentPolicy do
  def create? = described_class.new(client, :agent).create?

  context "with a client holding the right to register" do
    let(:client) { create(:oauth_application, :with_agent_registration_right) }

    it "allows the registration" do
      expect(create?).to be(true)
    end

    it "refuses it as soon as the right is withdrawn" do
      OauthApplicationRight.where(oauth_application: client).destroy_all

      expect(create?).to be(false)
    end
  end

  context "with a client without the right" do
    let(:client) { create(:oauth_application) }

    it "refuses the registration" do
      expect(create?).to be(false)
    end

    it "does not borrow the right of another client" do
      create(:oauth_application, :with_agent_registration_right)

      expect(create?).to be(false)
    end
  end
end
