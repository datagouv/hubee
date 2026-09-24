# frozen_string_literal: true

module Portail
  # Un nom de pièce tel qu'il peut finir sur le disque de l'agent. Il arrive verbatim du partenaire :
  # les caractères de contrôle et de mise en forme partent d'abord (un octet nul ferait lever
  # `basename`, une inversion de sens d'écriture ferait passer un `.exe` pour un `.pdf`), puis seul
  # le dernier segment survit, antislash compris. Sert aussi au numéro du télédossier et au dossier
  # de l'archive, qui finissent eux aussi sur ce disque.
  module SafeFilename
    class << self
      def for(name)
        safe = File.basename(name.to_s.gsub(/[\p{Cc}\p{Cf}]/, "").tr("\\", "/"))

        safe.delete("./").blank? ? Delivery::Attachment::FALLBACK_FILENAME : safe
      end
    end
  end
end
