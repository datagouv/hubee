# frozen_string_literal: true

require "rails_helper"

RSpec.describe PhoneNumber do
  describe ".normalize" do
    it "brings metropolitan numbers to E.164, whatever the separators" do
      expect(described_class.normalize("01 42 76 20 00")).to eq("+33142762000")
      expect(described_class.normalize("01.42.76.20.00")).to eq("+33142762000")
      expect(described_class.normalize("01-42-76-20-00")).to eq("+33142762000")
      expect(described_class.normalize("0142762000")).to eq("+33142762000")
      expect(described_class.normalize("06 12 34 56 78")).to eq("+33612345678")
    end

    it "reads the international forms an agent may paste" do
      expect(described_class.normalize("+33 1 42 76 20 00")).to eq("+33142762000")
      expect(described_class.normalize("0033142762000")).to eq("+33142762000")
      # Le (0) imprimé ne fait pas partie du numéro : le garder produirait
      # +330142762000, qui a la bonne forme sans être le bon numéro.
      expect(described_class.normalize("+33 (0)1 42 76 20 00")).to eq("+33142762000")
    end

    it "gives overseas landlines their own country code, not +33" do
      expect(described_class.normalize("0262 12 34 56")).to eq("+262262123456")
      expect(described_class.normalize("0263 12 34 56")).to eq("+262263123456")
      expect(described_class.normalize("0269 12 34 56")).to eq("+262269123456")
      expect(described_class.normalize("0590 12 34 56")).to eq("+590590123456")
      expect(described_class.normalize("0594 12 34 56")).to eq("+594594123456")
      expect(described_class.normalize("0596 12 34 56")).to eq("+596596123456")
    end

    # Les mobiles ultramarins ne partagent pas le préfixe des fixes : les omettre de la
    # table enverrait un numéro réunionnais sur +33.
    it "gives overseas mobiles their own country code too" do
      expect(described_class.normalize("0692 12 34 56")).to eq("+262692123456")
      expect(described_class.normalize("0693 12 34 56")).to eq("+262693123456")
      expect(described_class.normalize("0639 12 34 56")).to eq("+262639123456")
      expect(described_class.normalize("0690 12 34 56")).to eq("+590690123456")
      expect(described_class.normalize("0691 12 34 56")).to eq("+590691123456")
      expect(described_class.normalize("0694 12 34 56")).to eq("+594694123456")
      expect(described_class.normalize("0696 12 34 56")).to eq("+596696123456")
      expect(described_class.normalize("0697 12 34 56")).to eq("+596697123456")
    end

    # Nouvelle-Calédonie : plan de numérotation distinct, six chiffres sans zéro initial.
    # Ces numéros se saisissent en forme internationale et traversent sans transformation.
    it "leaves numbers from the Pacific collectivities untouched" do
      expect(described_class.normalize("+687 12 34 56")).to eq("+687123456")
    end

    it "has nothing to normalize in a blank value" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to be_nil
      expect(described_class.normalize("   ")).to be_nil
    end

    # Ce que la normalisation ne sait pas mettre en forme, elle le rend nettoyé plutôt que
    # de l'effacer : c'est la validation qui rejettera, et le producteur saura ce qu'il a
    # écrit. Effacer en silence perdrait la donnée sans le signaler à personne.
    it "returns what it cannot normalize instead of erasing it" do
      expect(described_class.normalize("12345")).to eq("12345")
      expect(described_class.normalize("01 42")).to eq("0142")
    end
  end
end
