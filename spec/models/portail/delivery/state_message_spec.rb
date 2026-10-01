# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::StateMessage do
  describe ".of" do
    it "keeps what the agent wrote, without the surrounding blanks" do
      expect(described_class.of("  Pièce illisible, merci de la renvoyer.\n")).to eq("Pièce illisible, merci de la renvoyer.")
    end

    it "carries nothing when the agent wrote nothing" do
      expect(described_class.of("")).to be_nil
      expect(described_class.of(" \r\n\t ")).to be_nil
      expect(described_class.of(nil)).to be_nil
    end

    # Le navigateur compte un retour à la ligne pour un caractère et en soumet deux : sans cette
    # normalisation, un texte accepté par le champ serait refusé au serveur.
    it "counts a line break the way the field does" do
      message = described_class.of("#{"a" * 249}\r\n#{"b" * 250}")

      expect(message).to eq("#{"a" * 249}\n#{"b" * 250}")
      expect(message.length).to eq(described_class::MAX_LENGTH)
    end

    it "carries nothing from a parameter that is not a text" do
      expect(described_class.of(["Pièce illisible"])).to be_nil
      expect(described_class.of({"texte" => "Pièce illisible"})).to be_nil
    end
  end
end
