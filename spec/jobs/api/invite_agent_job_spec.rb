# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::InviteAgentJob do
  include ActiveJob::TestHelper

  let(:agent) { create(:agent, email: "alice.martin@ville.fr") }

  let(:origin) do
    {siret: "21750056000016", insee_code: "75056", api_client: "systeme-interne", api_client_uid: "uid-123", request_id: "req-42"}
  end

  describe "on a temporary refusal of the mail server" do
    it "retries the delivery later" do
      delivery = instance_double(ActionMailer::MessageDelivery)
      expect(API::AgentMailer).to receive(:invitation).and_return(delivery)
      expect(delivery).to receive(:deliver_now).and_raise(Net::SMTPServerBusy.new("451 try again later"))

      expect { described_class.perform_now(agent, organization_name: nil, **origin) }
        .to change { enqueued_jobs.size }.by(1)
    end
  end

  describe "#perform" do
    it "delivers the invitation to the agent, naming the organisation" do
      described_class.perform_now(agent, organization_name: "Mairie de Paris", **origin)

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["alice.martin@ville.fr"])
      expect(mail.subject).to eq("[HubEE] Votre accès au portail HubEE")
      expect(mail.text_part.body.decoded).to include("l'organisation Mairie de Paris (SIRET 21750056000016)")
    end

    it "delivers it without a name when the referential had none" do
      described_class.perform_now(agent, organization_name: nil, **origin)

      expect(ActionMailer::Base.deliveries.last.text_part.body.decoded).to include("l'organisation de SIRET 21750056000016.")
    end

    it "traces the delivery on the agent, with the origin of the call and without name nor phone" do
      described_class.perform_now(agent, organization_name: "Mairie de Paris", **origin)

      expect(Event.sole).to have_attributes(
        eventable: agent,
        event_type: "agent.invited",
        metadata: {
          "api_client" => "systeme-interne",
          "api_client_uid" => "uid-123",
          "request_id" => "req-42",
          "email" => "alice.martin@ville.fr",
          "siret" => "21750056000016",
          "insee_code" => "75056"
        }
      )
    end

    it "traces nothing and lets the error rise when the delivery fails" do
      delivery = instance_double(ActionMailer::MessageDelivery)
      expect(API::AgentMailer).to receive(:invitation).and_return(delivery)
      expect(delivery).to receive(:deliver_now).and_raise(Net::SMTPFatalError.new("550 refused"))

      expect { described_class.perform_now(agent, organization_name: nil, **origin) }
        .to raise_error(Net::SMTPFatalError)
      expect(Event.count).to eq(0)
    end

    it "sends and traces nothing again for an agent already invited" do
      described_class.perform_now(agent, organization_name: nil, **origin)

      expect { described_class.perform_now(agent, organization_name: nil, **origin) }
        .not_to change { [ActionMailer::Base.deliveries.size, Event.count] }
    end

    it "sends and traces nothing for an agent deleted since the enqueue" do
      described_class.perform_later(agent, organization_name: nil, **origin)
      agent.destroy!

      expect { perform_enqueued_jobs }.not_to change { [ActionMailer::Base.deliveries.size, Event.count] }
    end
  end
end
