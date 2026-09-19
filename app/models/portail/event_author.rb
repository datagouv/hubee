# frozen_string_literal: true

module Portail
  # Le nom qui signe un événement écrit en amont. ⚠️ Il est publié : l'émetteur du dossier le lit.
  module EventAuthor
    # Nom de famille en capitales, comme l'administration écrit une identité. Les deux champs sont
    # nuls tant qu'un agent n'a pas ouvert de session ; celui qui écrit en a forcément une.
    def self.for(agent)
      [agent.first_name, agent.last_name&.upcase].compact_blank.join(" ")
    end
  end
end
