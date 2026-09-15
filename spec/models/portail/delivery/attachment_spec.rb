# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::Attachment do
  describe "#received?" do
    attachment_states = {
      "received" => {received: true},
      "pending" => {received: false},
      "corrupted" => {received: false},
      "rejected" => {received: false},
      "deleted" => {received: false},
      "unknown" => {received: false}
    }

    attachment_states.each do |state, expectation|
      it "is #{expectation[:received]} for a #{state} piece" do
        expect(build(:portail_attachment, state: state).received?).to be(expectation[:received])
      end
    end
  end
end
