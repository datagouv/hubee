# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::Reauthentication do
  let(:provider_session) { create(:provider_session) }
  let(:purpose) { described_class.purpose(:credentials, "subscription-a") }

  def prove(purpose: self.purpose)
    described_class.record!(provider_session, purpose:, id_token: "fresh-id-token", acr: "eidas1-mfa", amr: ["mfa"])
  end

  before { freeze_time }

  it "names a purpose after the action and its subject" do
    expect(purpose).to eq("credentials:subscription-a")
  end

  # Chaque action sensible est classée une seule fois : le garde et l'affichage en tirent le niveau.
  it "classes the consultation of credentials as very sensitive" do
    expect(described_class.level(:credentials)).to eq(:very_sensitive)
  end

  it "rejects an action that is not classed" do
    expect { described_class.level(:export) }.to raise_error(ArgumentError, /export/)
  end

  describe ".unlocked_until" do
    def unlocked_until(subject_id = "subscription-a")
      described_class.unlocked_until(provider_session, action: :credentials, subject_id:)
    end

    it "gives the end of the window of a proof for this action on this subject" do
      prove

      expect(unlocked_until).to eq(5.minutes.from_now)
    end

    it "gives nothing without a proof, for another subject, or once consumed" do
      expect(unlocked_until).to be_nil

      prove
      expect(unlocked_until("subscription-b")).to be_nil

      described_class.consume!(provider_session, purpose:)
      expect(unlocked_until).to be_nil
    end

    it "gives nothing once the window has passed" do
      prove
      travel 5.minutes + 1.second

      expect(unlocked_until).to be_nil
    end
  end

  it "is not satisfied without any reauthentication" do
    expect(described_class.satisfied?(provider_session, level: :sensitive, purpose:)).to be(false)
    expect(described_class.satisfied?(provider_session, level: :very_sensitive, purpose:)).to be(false)
  end

  it "records the proof along with the session's new ProConnect token" do
    prove

    expect(provider_session.reload).to have_attributes(reauthenticated_at: Time.current, reauthenticated_for: purpose,
      reauthentication_consumed_at: nil, provider_id_token: "fresh-id-token", acr: "eidas1-mfa", amr: ["mfa"])
  end

  # Une réauthentification prouve la fraîcheur, quelle que soit l'action qui l'a demandée.
  it "satisfies the sensitive level within 30 minutes, consumed or not" do
    prove
    described_class.consume!(provider_session, purpose:)

    travel 29.minutes
    expect(described_class.satisfied?(provider_session, level: :sensitive, purpose: "other:1")).to be(true)

    travel 2.minutes
    expect(described_class.satisfied?(provider_session, level: :sensitive, purpose: "other:1")).to be(false)
  end

  it "satisfies the very sensitive level only for its purpose, within 5 minutes, once" do
    prove

    travel 4.minutes
    expect(described_class.satisfied?(provider_session, level: :very_sensitive, purpose:)).to be(true)
    expect(described_class.satisfied?(provider_session, level: :very_sensitive,
      purpose: described_class.purpose(:credentials, "subscription-b"))).to be(false)

    described_class.consume!(provider_session, purpose:)
    expect(described_class.satisfied?(provider_session, level: :very_sensitive, purpose:)).to be(false)
  end

  it "lets a very sensitive proof expire after 5 minutes" do
    prove

    travel 6.minutes

    expect(described_class.satisfied?(provider_session, level: :very_sensitive, purpose:)).to be(false)
    expect(described_class.consume!(provider_session, purpose:)).to be(false)
  end

  it "consumes a proof only once" do
    prove

    expect(described_class.consume!(provider_session, purpose:)).to be(true)
    expect(described_class.consume!(provider_session, purpose:)).to be(false)
  end

  it "does not consume a proof obtained for another purpose" do
    prove(purpose: described_class.purpose(:credentials, "subscription-b"))

    expect(described_class.consume!(provider_session, purpose:)).to be(false)
  end

  # Une nouvelle réauthentification remplace la précédente, consommée ou non.
  it "renews a consumed proof with a new reauthentication" do
    prove
    described_class.consume!(provider_session, purpose:)

    prove

    expect(described_class.consume!(provider_session, purpose:)).to be(true)
  end
end
