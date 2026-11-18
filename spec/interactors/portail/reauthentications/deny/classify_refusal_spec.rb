# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Deny::ClassifyRefusal do
  def classify(error) = described_class.call(error:)

  # Quelqu'un d'autre que le rattachement de la session est revenu : le collègue au poste.
  it "closes the session as a mismatch for anyone but the session's membership" do
    %i[reauthentication_mismatch unknown_agent email_mismatch organization_mismatch].each do |error|
      expect(classify(error)).to have_attributes(reason: :reauthentication_mismatch, close_session: true, traced: true)
    end
  end

  # La déconnexion a été évitée : quelqu'un au poste a pu empêcher la redirection.
  it "closes the session when the logout did not happen" do
    expect(classify(:reauthentication_without_logout))
      .to have_attributes(reason: :reauthentication_without_logout, close_session: true, traced: true)
  end

  # Un abandon, un refus de ProConnect ou une panne ne disent rien de qui est au poste.
  it "keeps the session on any other refusal, traced under its own reason" do
    %i[reauthentication_aborted second_factor_required insufficient_authentication_level].each do |error|
      expect(classify(error)).to have_attributes(reason: error, close_session: false, traced: true)
    end
  end

  # Un jeton invalide est déjà tracé par sa vérification ; une panne n'est imputable à personne.
  it "leaves an invalid token and an outage untraced" do
    %i[invalid_token provider_unavailable].each do |error|
      expect(classify(error)).to have_attributes(close_session: false, traced: false)
    end
  end
end
