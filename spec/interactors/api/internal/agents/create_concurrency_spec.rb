# frozen_string_literal: true

require "rails_helper"

# L'import enregistre en parallèle, et les premiers agents d'une organisation arrivent ensemble.
# Deux connexions doivent voir leurs écritures respectives : pas de transaction de test englobante,
# donc un nettoyage à la main, limité à ce fichier.
RSpec.describe API::Internal::Agents::Create do
  self.use_transactional_tests = false

  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }

  after do
    [Event, DataStreamAccess, Membership, Agent, OrganizationLink].each(&:delete_all)
  end

  describe ".call" do
    it "registers two first agents of an organisation at the same time under a single link" do
      # Les deux appels se retrouvent après avoir constaté l'organisation inconnue de la V2, puis
      # chacun garde sa transaction ouverte sur ses traces : l'autre cherche le lien sans le voir.
      barrier = Concurrent::CyclicBarrier.new(2)
      stub_hub_api_v2_data_stream(code: "CERTDC")
      expect(API::HubAPI::Organizations).to receive(:verify).twice do
        raise "barrier timed out" unless barrier.wait(5)
        true
      end
      expect(Event).to receive(:create!).exactly(4).times.and_wrap_original do |original, **attributes|
        sleep 0.2
        original.call(**attributes)
      end

      results = %w[alice.martin@ville.fr bruno.durand@ville.fr].map { |email|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.call(form: build(:api_internal_agent_form, email:), api_client:, request_id: email)
          end
        end
      }.map(&:value)

      expect(results).to all(be_success)
      expect(OrganizationLink.pluck(:siret, :insee_code)).to eq([["21750056000016", "75056"]])
      expect(Membership.pluck(:organization_link_id).uniq).to eq([OrganizationLink.sole.id])
      expect(Agent.pluck(:email)).to contain_exactly("alice.martin@ville.fr", "bruno.durand@ville.fr")
    end

    # Tout rejeu est refusé comme déjà rattaché, même quand l'appel rejoué part en même temps.
    it "refuses as already attached the same registration sent twice at the same time" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:organization_link, siret: "21750056000016", insee_code: "75056")
      # Les deux appels passent leurs vérifications ensemble sans voir de rattachement. Le verrou sur
      # l'agent fait attendre le second jusqu'à la fin de la transaction du premier : la validation
      # d'unicité voit alors le rattachement.
      barrier = Concurrent::CyclicBarrier.new(2)
      stub_hub_api_v2_data_stream(code: "CERTDC")
      expect(API::HubAPI::Organizations).to receive(:verify).twice do
        raise "barrier timed out" unless barrier.wait(5)
        true
      end
      expect(Event).to receive(:create!).once.and_wrap_original do |original, **attributes|
        sleep 0.2
        original.call(**attributes)
      end

      results = %w[req-1 req-2].map { |request_id|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            form = build(:api_internal_agent_form, email: "alice.martin@ville.fr")
            described_class.call(form:, api_client:, request_id:)
          end
        end
      }.map(&:value)

      expect(results.map(&:success?)).to contain_exactly(true, false)
      expect(results.reject(&:success?).sole.refusals).to eq([:already_attached])
      expect(Membership.pluck(:agent_id)).to eq([agent.id])
      expect(Event.pluck(:event_type)).to eq(["membership.created"])
    end

    # Même une insertion hors de ce code attend le verrou : la clé étrangère vers l'agent l'exige.
    # L'index n'est donc atteint que sans verrou (exemple suivant).
    it "makes an attachment written outside this code wait for the lock" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      organization_link = create(:organization_link, siret: "21750056000016", insee_code: "75056")
      stub_hub_api_v2_data_stream(code: "CERTDC")
      expect(API::HubAPI::Organizations).to receive(:verify).and_return(true)
      outside = nil
      expect(Membership).to receive(:create!).and_wrap_original do |original, **attributes|
        outside = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            connection.transaction do
              connection.execute("SET LOCAL lock_timeout = '1s'")
              Membership.insert({agent_id: agent.id, organization_link_id: organization_link.id})
            end
            nil
          rescue ActiveRecord::LockWaitTimeout => e
            e.class
          end
        end
        # L'insertion ne peut obtenir le verrou tenu ici : l'attendre, c'est attendre son abandon.
        outside.join
        original.call(**attributes)
      end

      result = described_class.call(form: build(:api_internal_agent_form, email: "alice.martin@ville.fr"),
        api_client:, request_id: "req-1")

      expect(outside.value).to eq(ActiveRecord::LockWaitTimeout)
      expect(result).to be_success
      expect(Membership.where(agent:).count).to eq(1)
    end

    # Sans verrou, la validation du second ne voit pas le rattachement non commité du premier :
    # l'index l'arrête, le rescue le traduit.
    it "still refuses as already attached through the unique index once the lock is gone" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:organization_link, siret: "21750056000016", insee_code: "75056")
      expect(Agent).to receive(:lock).twice.and_return(Agent.all)
      barrier = Concurrent::CyclicBarrier.new(2)
      stub_hub_api_v2_data_stream(code: "CERTDC")
      expect(API::HubAPI::Organizations).to receive(:verify).twice do
        raise "barrier timed out" unless barrier.wait(5)
        true
      end
      raised = Queue.new
      expect(Membership).to receive(:create!).twice.and_wrap_original do |original, **attributes|
        original.call(**attributes)
      rescue => e
        raised << e.class
        raise
      end
      expect(Event).to receive(:create!).once.and_wrap_original do |original, **attributes|
        sleep 0.2
        original.call(**attributes)
      end

      results = %w[req-1 req-2].map { |request_id|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            form = build(:api_internal_agent_form, email: "alice.martin@ville.fr")
            described_class.call(form:, api_client:, request_id:)
          end
        end
      }.map(&:value)

      expect(results.map(&:success?)).to contain_exactly(true, false)
      expect(results.reject(&:success?).sole.refusals).to eq([:already_attached])
      expect(Array.new(raised.size) { raised.pop }).to eq([ActiveRecord::RecordNotUnique])
      expect(Membership.where(agent:).count).to eq(1)
      expect(Event.pluck(:event_type)).to eq(["membership.created"])
    end

    # Un seul rattachement par SIRET, même pour deux appels qui partent ensemble sous deux codes
    # guichet. Aucun index ne tient cet invariant, qui traverse une jointure.
    it "refuses as attached to the SIRET the same agent registered at the same time under another insee code" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      # Les deux appels se retrouvent après leurs vérifications, et le premier garde sa transaction
      # ouverte sur sa trace : sans verrou, la validation du second ne verrait pas le rattachement.
      barrier = Concurrent::CyclicBarrier.new(2)
      stub_hub_api_v2_data_stream(code: "CERTDC")
      expect(API::HubAPI::Organizations).to receive(:verify).twice do
        raise "barrier timed out" unless barrier.wait(5)
        true
      end
      expect(Event).to receive(:create!).once.and_wrap_original do |original, **attributes|
        sleep 0.2
        original.call(**attributes)
      end

      results = %w[75056 75101].map { |insee_code|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            form = build(:api_internal_agent_form, email: "alice.martin@ville.fr", insee_code:)
            described_class.call(form:, api_client:, request_id: insee_code)
          end
        end
      }.map(&:value)

      expect(results.map(&:success?)).to contain_exactly(true, false)
      expect(results.reject(&:success?).sole.refusals).to eq([:siret_already_attached])
      expect(Membership.pluck(:agent_id)).to eq([agent.id])
    end
  end
end
