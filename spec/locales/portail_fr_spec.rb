# frozen_string_literal: true

require "rails_helper"

# Le tiret cadratin se lit comme un texte généré ; le DSFR sépare par « - ».
RSpec.describe "Portail French translations" do
  def leaves(node, path = [])
    return [[path.join("."), node]] unless node.is_a?(Hash)

    node.flat_map { |key, value| leaves(value, path + [key]) }
  end

  it "shows no em dash to the agent" do
    translations = leaves(I18n.t("portail", locale: :fr))

    expect(translations).not_to be_empty
    expect(translations.select { |_key, text| text.to_s.include?("—") }).to eq([])
  end
end
