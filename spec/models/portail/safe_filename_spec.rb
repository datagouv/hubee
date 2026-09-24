# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::SafeFilename do
  describe ".for" do
    filenames = {
      "a plain filename" => {input: "certificat.pdf", expected: "certificat.pdf"},
      "a path, backslashes included" => {input: "..\\..\\/tmp/rap\r\nport.pdf", expected: "rapport.pdf"},
      # Un octet nul ferait lever la réduction au dernier segment : il part avant.
      "a null byte" => {input: "rap\u0000port.pdf", expected: "rapport.pdf"},
      # Une inversion de sens d'écriture ferait lire « rapportexe.pdf » pour un fichier « .exe ».
      "a right-to-left override" => {input: "rapport‮fdp.exe", expected: "rapportfdp.exe"},
      "an accented filename" => {input: "décision n°1.pdf", expected: "décision n°1.pdf"},
      "dots only" => {input: "..", expected: "piece"},
      "an empty filename" => {input: "", expected: "piece"},
      "no filename at all" => {input: nil, expected: "piece"}
    }

    filenames.each do |situation, filename|
      it "returns #{filename[:expected].inspect} for #{situation}" do
        expect(described_class.for(filename[:input])).to eq(filename[:expected])
      end
    end
  end
end
