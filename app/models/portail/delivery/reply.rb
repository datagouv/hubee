# frozen_string_literal: true

module Portail
  class Delivery
    # La réponse que l'agent joint au télédossier : en V2, un paquet enfant porteur d'une pièce.
    # Le type se lit dans le contenu, le nom ne précisant qu'un contenu sans signature.
    class Reply < Data.define(:filename, :content_type, :byte_size, :file)
      MAX_FILENAME_LENGTH = 255

      # Un paramètre qui n'est pas un fichier téléversé ne porte aucune réponse.
      def self.of(param)
        return unless param.is_a?(ActionDispatch::Http::UploadedFile)

        new(
          # Le dernier segment seul ; un nom réduit à des séparateurs n'en laisse aucun.
          filename: File.basename(param.original_filename.to_s.tr("\\", "/")).delete("/"),
          content_type: Marcel::MimeType.for(param.tempfile, name: param.original_filename),
          byte_size: param.size,
          file: param
        )
      end

      def bytes
        file.rewind
        file.read.b
      end
    end
  end
end
