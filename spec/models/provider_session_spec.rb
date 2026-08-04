# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProviderSession, type: :model do
  describe "validations" do
    subject { build(:provider_session) }

    it { is_expected.to validate_presence_of(:provider_id_token) }
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "associations" do
    # Optionnel : un refus « compte inconnu » n'a ni rattachement, ni agent.
    it { is_expected.to belong_to(:membership).optional }
  end

  # Le prédicat lit la clé étrangère, comme le scope `granted` : les faire diverger
  # rendrait possible qu'un enregistrement soit accordé pour l'un et refusé pour l'autre.
  describe "#granted?" do
    it "tells an open session from a refused authentication" do
      expect(create(:provider_session)).to be_granted
      expect(create(:provider_session, :denied)).not_to be_granted
    end
  end

  describe "scopes" do
    it "separates open sessions from refusals" do
      granted = create(:provider_session)
      denied = create(:provider_session, :denied)

      expect(described_class.granted).to contain_exactly(granted)
      expect(described_class.denied).to contain_exactly(denied)
    end
  end

  # La cascade vit en base : elle ne se contourne ni par delete_all, ni par du SQL direct.
  describe "when the membership is revoked" do
    it "goes away with it" do
      provider_session = create(:provider_session)

      expect { provider_session.membership.destroy }
        .to change(described_class, :count).by(-1)
    end
  end
end
