# frozen_string_literal: true

require "rails_helper"

# ProConnect ouvre un nouveau `sid` après une déconnexion : le même `sid` au retour prouve que la
# déconnexion n'a pas eu lieu, et que la connexion a réutilisé la session ProConnect déjà ouverte.
RSpec.describe Portail::Reauthentications::Complete::CheckLoggedOut do
  let(:provider_session) { create(:provider_session, provider_sid: "sid-before") }

  it "passes when ProConnect opened a new session" do
    expect(described_class.call(provider_session:, claims: {sid: "sid-after"})).to be_success
  end

  it "fails when ProConnect reused the session of the sign-in" do
    result = described_class.call(provider_session:, claims: {sid: "sid-before"})

    expect(result.error).to eq(:reauthentication_without_logout)
  end

  # Sans `sid`, rien ne prouve la déconnexion : la preuve est refusée plutôt que supposée.
  it "fails when ProConnect does not say which session it used" do
    result = described_class.call(provider_session:, claims: {sid: nil})

    expect(result.error).to eq(:reauthentication_without_logout)
  end

  # Une session sans `sid` rangé n'a rien à comparer : n'importe quel `sid` au retour passerait pour
  # une déconnexion. Refusé, sous son propre motif : rien n'y dit que la déconnexion a été évitée.
  it "fails when the session has no sid to compare with, whatever ProConnect returns" do
    legacy_session = create(:provider_session, provider_sid: nil)

    result = described_class.call(provider_session: legacy_session, claims: {sid: "sid-after"})

    expect(result.error).to eq(:reauthentication_unprovable)
  end
end
