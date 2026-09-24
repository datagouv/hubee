# frozen_string_literal: true

module Portail
  # L'écrivain zip des pièces d'un télédossier, pièce par pièce dans un fichier déjà ouvert, sous un
  # sous-dossier. Compense localement une route d'archive absente chez hub-api.
  class Archive
    # Le deflater rend d'un bloc ce qu'il reçoit d'un bloc : par tranches, il ne double pas la
    # pièce en mémoire.
    CHUNK_SIZE = 1.megabyte

    # Ce que Windows refuse à l'extraction, propre aux entrées : l'en-tête d'une pièce seule n'y est
    # pas soumis. Les barres pleine chasse aussi : la conversion « best fit » de Windows les ramène
    # aux barres ASCII. 200 octets laissent au suffixe de doublon sa marge sous la limite de 255.
    FORBIDDEN_CHARACTERS = /[:*?"<>|／＼]/
    TRAILING_DOTS_AND_SPACES = /[. ]+\z/
    RESERVED_NAME = /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|\z)/i
    MAX_NAME_BYTES = 200

    class << self
      # Le répertoire central s'écrit au retour du bloc.
      def write(io, folder)
        # rubyzip écrit sur une copie du descripteur : elle ne doit pas survivre à l'écriture.
        # Si le bloc lève, `close!` de l'original supprime le fichier ; la copie attend le GC.
        Zip::OutputStream.write_buffer(io) { |zip| yield new(zip, folder) }.close
      end
    end

    def initialize(zip, folder)
      @zip = zip
      @folder = entry_name(folder)
      @taken = Set.new
      # Le format DOS ne porte pas de fuseau : l'heure de Paris, comme le nom de l'archive.
      @time = Zip::DOSTime.from_time(Time.current.in_time_zone("Europe/Paris"))
    end

    def add(filename, content)
      entry = Zip::Entry.new("", "#{@folder}/#{unique(entry_name(filename))}", time: @time)
      # Sans le drapeau UTF-8, un nom accentué s'extrait illisible.
      entry.gp_flags |= Zip::Entry::EFS
      @zip.put_next_entry(entry)
      0.step(content.bytesize - 1, CHUNK_SIZE) { |offset| @zip << content.byteslice(offset, CHUNK_SIZE) }
    end

    private

    # NFC d'abord : le même nom en NFD, courant depuis macOS, échapperait à la détection des
    # doublons.
    def entry_name(name)
      safe = truncated(SafeFilename.for(name).unicode_normalize(:nfc).gsub(FORBIDDEN_CHARACTERS, "_"))
        .sub(TRAILING_DOTS_AND_SPACES, "").presence || Delivery::Attachment::FALLBACK_FILENAME

      RESERVED_NAME.match?(safe) ? "_#{safe}" : safe
    end

    # Un caractère coupé par la limite part entier plutôt que de laisser un octet invalide.
    def truncated(name)
      return name if name.bytesize <= MAX_NAME_BYTES

      extension = File.extname(name)
      extension = "" if extension.bytesize >= MAX_NAME_BYTES
      name.delete_suffix(extension).byteslice(0, MAX_NAME_BYTES - extension.bytesize).scrub("") + extension
    end

    # Casse ignorée : deux noms qui ne diffèrent que par elle s'écraseraient à l'extraction sur un
    # disque insensible à la casse.
    def unique(name)
      extension = File.extname(name)
      candidate = name
      suffix = 0
      until @taken.add?(candidate.downcase)
        suffix += 1
        candidate = "#{name.delete_suffix(extension)}-#{suffix}#{extension}"
      end
      candidate
    end
  end
end
