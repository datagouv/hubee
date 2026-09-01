# frozen_string_literal: true

module Portail
  # De quoi dessiner le pied de liste. Le total est affiché avant la première ligne : douze
  # dossiers ou sept cents ne se lisent pas de la même façon, et ça ne se déduit pas d'un
  # numéro de dernière page.
  Pagination = Data.define(:current_page, :total_pages, :total)
end
