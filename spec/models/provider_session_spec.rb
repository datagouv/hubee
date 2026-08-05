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

  # Deux bornes indépendantes : l'inactivité et la durée absolue. Une session entretenue
  # par de l'activité ne doit pas pouvoir durer indéfiniment.
  describe "#expired?" do
    it "closes on inactivity, on absolute age, and on neither before that" do
      expect(create(:provider_session, updated_at: 31.minutes.ago)).to be_expired
      expect(create(:provider_session, created_at: 13.hours.ago)).to be_expired
      expect(create(:provider_session, created_at: 11.hours.ago, updated_at: 1.minute.ago))
        .not_to be_expired
    end
  end

  describe "scopes" do
    # Le pendant SQL de `expired?` : les faire diverger laisserait la purge derrière.
    it "gathers exactly the sessions the predicate calls expired" do
      idle = create(:provider_session, updated_at: 31.minutes.ago)
      exhausted = create(:provider_session, created_at: 13.hours.ago)
      create(:provider_session)
      # Un refus n'est pas une session ouverte : il relève de sa propre rétention.
      create(:provider_session, :denied, created_at: 13.hours.ago)

      expect(described_class.expired).to contain_exactly(idle, exhausted)
    end

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
