# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::States::Update::WriteReply do
  let(:membership) do
    create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end
  let(:delivery) { build(:portail_delivery, state: "in_progress") }

  let(:reply) { portail_reply }

  def publish(author: "Camille MARTIN", with: reply)
    described_class.call(membership: membership, delivery: delivery, author: author, reply: with)
  end

  it "does nothing when no reply is joined" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)

    expect(publish(with: nil)).to be_a_success
  end

  # Le couple vient du rattachement, pris ailleurs il ouvrirait une autre structure.
  it "publishes the reply within the organisation of the membership, under the agent name" do
    expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).with(
      id: delivery.id, reply: reply, author: "Camille MARTIN",
      siret: "22770001000019", insee_code: "77372"
    ).and_return(build(:portail_event, event_type: "attachment.created"))

    expect(publish.reply_sent).to be(true)
  end

  it "refuses before publishing when the agent has no name to sign with" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:reply_with_attachment)

    expect(publish(author: "").error).to eq(:unknown_author)
  end

  {
    Portail::HubAPI::AttachmentContentTypeNotAccepted => :attachment_format,
    Portail::HubAPI::AttachmentInfected => :attachment_infected,
    Portail::HubAPI::AttachmentContentMismatch => :attachment_content_mismatch,
    Portail::HubAPI::NotFound => :not_found,
    Portail::HubAPI::EventLimitReached => :event_limit_reached,
    Portail::HubAPI::InvalidRequest => :rejected,
    Portail::HubAPI::Unavailable => :attachment_unconfirmed
  }.each do |raised, error|
    it "fails with #{error} when the upstream raises #{raised.name.demodulize}" do
      expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_raise(raised)

      result = publish

      expect(result.error).to eq(error)
      expect(result.reply_sent).to be_nil
    end
  end

  # Une garde du portail a manqué : le support doit l'apprendre, l'agent ne peut rien y faire.
  it "reports a publication the upstream rejects as a portal defect" do
    expect(Portail::HubAPI::Deliveries).to receive(:reply_with_attachment).and_raise(Portail::HubAPI::InvalidRequest)
    expect(Rails.error).to receive(:report).with(instance_of(Portail::HubAPI::InvalidRequest), handled: true)

    publish
  end
end
