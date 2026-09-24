# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Archive do
  let(:folder) { "20260923-14.05_DOSSIER-42" }

  # Relue par le répertoire central, comme la lit un outil d'extraction. Les noms sont lus tels
  # quels : c'est le drapeau UTF-8 qui dit comment les décoder.
  def entries_of(pieces, folder: self.folder)
    file = Tempfile.new("archive", binmode: true)
    described_class.write(file, folder) do |archive|
      pieces.each { |filename, content| archive.add(filename, content) }
    end
    Zip::File.open(file.path) { |zip| zip.entries.map { |entry| read(entry) } }
  ensure
    file&.close!
  end

  def read(entry)
    {name: entry.name.dup.force_encoding(Encoding::UTF_8), utf8: entry.gp_flags.anybits?(Zip::Entry::EFS),
     size: entry.size, time: entry.time, body: entry.get_input_stream.read}
  end

  def names_of(filenames, folder: self.folder)
    entries_of(filenames.map { |filename| [filename, "octets".b] }, folder:).map { |entry| entry[:name] }
  end

  describe ".write" do
    it "writes each piece, in order, under the folder, as the central directory lists it" do
      first = "%PDF-1.7\n\xFF\xFE\x00premier".b

      entries = entries_of([["certificat.pdf", first], ["annexe.xml", "<annexe/>".b]])

      expect(entries.map { |entry| entry.slice(:name, :size, :body) }).to eq([
        {name: "#{folder}/certificat.pdf", size: first.bytesize, body: first},
        {name: "#{folder}/annexe.xml", size: 9, body: "<annexe/>"}
      ])
    end

    it "suffixes a duplicate before its extension" do
      names = names_of(["notes", "notes-1", "notes", "rapport.v2.pdf", "rapport.v2.pdf"])

      expect(names).to eq(%W[#{folder}/notes #{folder}/notes-1 #{folder}/notes-2
        #{folder}/rapport.v2.pdf #{folder}/rapport.v2-1.pdf])
    end

    # Sur un disque insensible à la casse, le second écraserait le premier à l'extraction.
    it "ignores case when telling duplicates" do
      expect(names_of(["certificat.pdf", "Certificat.PDF"]))
        .to eq(["#{folder}/certificat.pdf", "#{folder}/Certificat-1.PDF"])
    end

    # Le même nom en NFD, courant depuis macOS, et en NFC : un seul fichier à l'extraction.
    it "normalizes the names to NFC before telling duplicates" do
      expect(names_of(["décision.pdf", "décision.pdf"]))
        .to eq(["#{folder}/décision.pdf", "#{folder}/décision-1.pdf"])
    end

    it "keeps the entries inside a folder that climbs out" do
      expect(names_of(["certificat.pdf"], folder: "../../#{folder}")).to eq(["#{folder}/certificat.pdf"])
    end

    it "sanitizes the names of the pieces" do
      expect(names_of(["..\\..\\certificat.pdf", "rap\u0000port.pdf", ".."]))
        .to eq(["#{folder}/certificat.pdf", "#{folder}/rapport.pdf", "#{folder}/piece"])
    end

    # Sans le drapeau, un nom accentué s'extrait illisible.
    it "flags the names as UTF-8" do
      entry = entries_of([["décision.xml", "<décision/>".b]]).first

      expect(entry).to include(name: "#{folder}/décision.xml", utf8: true)
    end

    # Au-delà d'une tranche, la pièce s'écrit en plusieurs fois et doit se relire à l'identique.
    it "keeps a piece larger than a chunk intact" do
      body = Random.new(42).bytes((2.5 * described_class::CHUNK_SIZE).to_i)

      expect(entries_of([["gros.bin", body]]).first).to include(size: body.bytesize, body: body)
    end

    it "writes an empty piece as an empty entry" do
      expect(entries_of([["vide.txt", "".b]]).first).to include(name: "#{folder}/vide.txt", size: 0, body: "")
    end

    # Le nom de l'archive dit l'heure de Paris : ses entrées aussi, quel que soit le fuseau du
    # processus. Le format DOS ne porte pas de fuseau, l'heure se lit telle quelle.
    it "stamps the entries with the time in Paris, whatever the zone of the process" do
      zone = ENV["TZ"]
      ENV["TZ"] = "UTC"

      entry = travel_to(Time.utc(2026, 1, 15, 13, 5)) { entries_of([["certificat.pdf", "octets".b]]).first }

      expect(entry[:time]).to have_attributes(year: 2026, month: 1, day: 15, hour: 14, min: 5)
    ensure
      ENV["TZ"] = zone
    end

    # Ce que Windows refuse à l'extraction, pour les pièces comme pour le dossier.
    context "with names Windows would refuse" do
      it "replaces the characters Windows forbids" do
        expect(names_of(["a:b*c?d\"e<f>g|h.pdf"])).to eq(["#{folder}/a_b_c_d_e_f_g_h.pdf"])
      end

      # Ramenées aux barres ASCII à l'extraction, elles feraient sortir le nom du dossier.
      it "replaces the fullwidth slashes" do
        expect(names_of(["..／..＼certificat.pdf"])).to eq(["#{folder}/.._.._certificat.pdf"])
      end

      it "drops the trailing dots and spaces" do
        expect(names_of(["rapport.pdf. . ", "notes..."])).to eq(["#{folder}/rapport.pdf", "#{folder}/notes"])
      end

      it "prefixes the reserved device names, with or without extension, whatever their case" do
        names = names_of(["CON", "con.txt", "Lpt9.pdf", "COM1", "nul.tar.gz", "PRN", "aux.", "CONSOLE.txt", "COM10"])

        expect(names).to eq(%W[#{folder}/_CON #{folder}/_con.txt #{folder}/_Lpt9.pdf #{folder}/_COM1
          #{folder}/_nul.tar.gz #{folder}/_PRN #{folder}/_aux #{folder}/CONSOLE.txt #{folder}/COM10])
      end

      it "truncates a long name to 200 bytes, keeping its extension" do
        name = names_of(["a#{"é" * 150}.pdf"]).first.delete_prefix("#{folder}/")

        expect(name).to eq("a#{"é" * 97}.pdf")
        expect(name.bytesize).to eq(199)
        expect(name).to be_valid_encoding
      end

      it "cuts an extension too long to keep with the rest of the name" do
        name = names_of(["a.#{"b" * 250}"]).first.delete_prefix("#{folder}/")

        expect(name).to eq("a.#{"b" * 198}")
      end

      it "falls back to a neutral name when truncation leaves only dots" do
        expect(names_of(["#{"." * 250}x"])).to eq(["#{folder}/piece"])
      end

      it "applies the same rules to the folder" do
        expect(names_of(["certificat.pdf"], folder: "20260923-14.05_CON:42. ")).to eq(["20260923-14.05_CON_42/certificat.pdf"])
      end
    end
  end
end
