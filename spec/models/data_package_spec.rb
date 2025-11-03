require "rails_helper"

RSpec.describe DataPackage, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:data_stream) }
    it { is_expected.to belong_to(:sender_organization).class_name("Organization") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
  end

  describe "database constraints" do
    let(:data_package) { create(:data_package) }

    it "prevents deletion when data_stream is destroyed" do
      data_stream = data_package.data_stream
      expect { data_stream.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end

    it "prevents deletion when sender_organization is destroyed" do
      sender_organization = data_package.sender_organization
      expect { sender_organization.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end

    it "enforces state check constraint" do
      expect {
        data_package.update_column(:state, "invalid_state")
      }.to raise_error(ActiveRecord::StatementInvalid, /state_check/)
    end
  end

  describe ".by_state" do
    let!(:pkg_draft) { create(:data_package, :draft) }
    let!(:pkg_transmitted) { create(:data_package, :transmitted) }
    let!(:pkg_ack) { create(:data_package, :acknowledged) }

    it "filters by single status" do
      expect(DataPackage.by_state("draft")).to contain_exactly(pkg_draft)
    end

    it "filters by multiple statuses as CSV" do
      expect(DataPackage.by_state("draft,transmitted")).to contain_exactly(pkg_draft, pkg_transmitted)
    end

    it "strips whitespace from CSV" do
      expect(DataPackage.by_state(" draft , acknowledged ")).to contain_exactly(pkg_draft, pkg_ack)
    end

    it "ignores invalid statuses and keeps valid ones" do
      expect(DataPackage.by_state("invalid,transmitted")).to contain_exactly(pkg_transmitted)
    end

    it "returns none when all statuses are invalid" do
      expect(DataPackage.by_state("invalid,unknown")).to be_empty
    end

    it "returns all when statuses is nil" do
      expect(DataPackage.by_state(nil)).to contain_exactly(pkg_draft, pkg_transmitted, pkg_ack)
    end

    it "returns all when statuses is not a string" do
      expect(DataPackage.by_state(["draft", "transmitted"])).to contain_exactly(pkg_draft, pkg_transmitted, pkg_ack)
    end
  end

  describe ".by_data_stream" do
    let(:stream1) { create(:data_stream) }
    let(:stream2) { create(:data_stream) }
    let!(:pkg1) { create(:data_package, data_stream: stream1) }
    let!(:pkg2) { create(:data_package, data_stream: stream2) }

    it "filters by data_stream_id" do
      expect(DataPackage.by_data_stream(stream1.id)).to contain_exactly(pkg1)
    end

    it "returns all when id is nil" do
      expect(DataPackage.by_data_stream(nil)).to contain_exactly(pkg1, pkg2)
    end
  end

  describe ".by_sender_organization" do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let!(:pkg1) { create(:data_package, sender_organization: org1) }
    let!(:pkg2) { create(:data_package, sender_organization: org2) }

    it "filters by sender_organization_id" do
      expect(DataPackage.by_sender_organization(org1.id)).to contain_exactly(pkg1)
    end

    it "returns all when id is nil" do
      expect(DataPackage.by_sender_organization(nil)).to contain_exactly(pkg1, pkg2)
    end
  end

  describe "#generate_title" do
    let(:data_stream) { create(:data_stream, name: "CertDC") }
    let(:data_package) { build(:data_package, data_stream: data_stream, title: nil) }

    it "generates title automatically on create when title is blank" do
      data_package.save!
      expect(data_package.title).to be_present
      expect(data_package.title).to match(/\ACertDC-\d{8}-\d{6}-[A-Z0-9]{4}\z/)
    end

    it "does not override provided title" do
      data_package.title = "Custom Title"
      data_package.save!
      expect(data_package.title).to eq("Custom Title")
    end

    it "includes data_stream name in title" do
      data_package.save!
      expect(data_package.title).to start_with("CertDC-")
    end

    it "includes timestamp and unique ID" do
      data_package.save!
      expect(data_package.title).to match(/\ACertDC-\d{8}-\d{6}-[A-Z0-9]{4}\z/)
    end
  end

  describe "AASM state machine" do
    describe "initial state" do
      it "starts in draft state" do
        package = DataPackage.new
        expect(package).to have_state(:draft)
      end
    end

    describe "send_package event" do
      context "with completed attachments" do
        let(:package) { create(:data_package, :draft) }
        before do
          allow(package).to receive(:has_completed_attachments?).and_return(true)
        end
        it "transitions from draft to transmitted" do
          expect(package).to transition_from(:draft).to(:transmitted).on_event(:send_package)
        end

        it "allows the event on draft packages" do
          expect(package).to allow_event(:send_package)
        end

        it "allows transition to transmitted from draft" do
          expect(package).to allow_transition_to(:transmitted)
        end
      end

      context "without completed attachments" do
        let(:package) { build(:data_package, :draft) }
        it "does not allow the event" do
          expect(package).to_not allow_event(:send_package)
        end
      end

      context "from transmitted state" do
        let(:package) { build(:data_package, :transmitted) }
        it "does not allow the event" do
          expect(package).to_not allow_event(:send_package)
        end
      end

      context "from acknowledged state" do
        let(:package) { build(:data_package, :acknowledged) }
        it "does not allow the event" do
          expect(package).to_not allow_event(:acknowledge)
        end
      end
    end

    describe "AASM error callbacks" do
      describe "#send_package! with error callback" do
        context "when guard fails" do
          let(:package) { create(:data_package, :draft) }

          before do
            allow(package).to receive(:has_completed_attachments?).and_return(false)
          end

          it "returns false" do
            expect(package.send_package!).to be false
          end

          it "does not transition" do
            package.send_package!
            expect(package).to have_state(:draft)
          end

          it "adds error to state via error callback" do
            package.send_package!
            expect(package.errors[:state]).to include("must be draft")
          end
        end

        context "when in wrong state" do
          let(:package) { create(:data_package, :transmitted) }

          it "returns false" do
            expect(package.send_package!).to be false
          end

          it "does not transition" do
            package.send_package!
            expect(package).to have_state(:transmitted)
          end

          it "adds error to state via error callback" do
            package.send_package!
            expect(package.errors[:state]).to include("must be draft")
          end
        end
      end
    end
  end

  describe "#can_be_destroyed?" do
    it "returns true for draft package" do
      package = build(:data_package, :draft)
      expect(package.can_be_destroyed?).to be true
    end

    it "returns false for sent package" do
      package = build(:data_package, :transmitted)
      expect(package.can_be_destroyed?).to be false
    end

    it "returns true for acknowledged package" do
      package = build(:data_package, :acknowledged)
      expect(package.can_be_destroyed?).to be true
    end
  end

  describe "implicit_order_column" do
    let!(:pkg1) { create(:data_package, :draft) }
    let!(:pkg2) { create(:data_package, :transmitted) }
    let!(:pkg3) { create(:data_package, :acknowledged) }

    it "orders .first and .last by created_at instead of UUID" do
      expect(DataPackage.first).to eq(pkg1)
      expect(DataPackage.last).to eq(pkg3)
    end
  end
end
