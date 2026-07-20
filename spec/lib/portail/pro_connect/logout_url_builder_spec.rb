# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::ProConnect::LogoutUrlBuilder do
  let(:discovery) do
    instance_double(Portail::ProConnect::Discovery,
      end_session_endpoint: "https://proconnect.gouv.fr/api/v2/session/end")
  end

  around do |example|
    original_redirect_uri = ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"]
    ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"] = "https://portail.hubee.gouv.fr/"
    example.run
  ensure
    ENV["PROCONNECT_POST_LOGOUT_REDIRECT_URI"] = original_redirect_uri
  end

  describe ".call" do
    it "builds the end_session URL with id_token_hint and post_logout_redirect_uri" do
      url = described_class.call(id_token: "the-id-token", discovery: discovery)
      params = Rack::Utils.parse_query(URI(url).query)

      expect(url).to start_with("https://proconnect.gouv.fr/api/v2/session/end?")
      expect(params).to eq(
        "id_token_hint" => "the-id-token",
        "post_logout_redirect_uri" => "https://portail.hubee.gouv.fr/"
      )
    end
  end
end
