# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::Decision do
  # Le Data ferme le jeu de clés ; cet exemple épingle lesquelles, comme pour Auth::Decision.
  it "carries these fields and no others" do
    expect(described_class.new(outcome: :refused).to_h.keys).to contain_exactly(
      :outcome, :path, :agent_id, :membership_id, :dropped_ids
    )
  end
end
