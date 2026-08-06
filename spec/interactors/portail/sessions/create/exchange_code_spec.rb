# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::ExchangeCode do
  it "unpacks what ProConnect returned into the context" do
    expect(Portail::ProConnect::Client).to receive(:exchange).with(code: "the-code").and_return(
      Portail::ProConnect::Client::Tokens.new(
        id_token: "raw-token",
        info: Portail::ProConnect::Client::Info.new(
          email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin"
        ),
        siret: "99999999911111", idp_id: "idp-1", organization_label: "Mairie de Test"
      )
    )

    result = described_class.call(code: "the-code")

    expect(result).to be_success
    expect(result.id_token).to eq("raw-token")
    expect(result.info.email).to eq("agent@example.gouv.fr")
    expect(result.siret).to eq("99999999911111")
    expect(result.idp_id).to eq("idp-1")
    expect(result.organization_label).to eq("Mairie de Test")
  end

  # ProConnect muet n'est pas une décision sur l'agent : le motif technique mène à la
  # page d'échec, pas à la page de refus.
  it "fails with provider_unavailable when ProConnect cannot be reached" do
    expect(Portail::ProConnect::Client).to receive(:exchange)
      .and_raise(Portail::ProConnect::Client::Unavailable, "boom")

    result = described_class.call(code: "the-code")

    expect(result).to be_failure
    expect(result.error).to eq(:provider_unavailable)
  end
end
