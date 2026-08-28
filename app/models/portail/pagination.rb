# frozen_string_literal: true

module Portail
  # De quoi dessiner le pied de liste, et rien de plus : le total et la taille de page servis
  # en amont ne sont affichés nulle part.
  Pagination = Data.define(:current_page, :total_pages)
end
