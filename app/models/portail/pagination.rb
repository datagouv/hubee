# frozen_string_literal: true

module Portail
  # De quoi dessiner le pied de liste, et l'échelle de ce qu'on parcourt. Le total est affiché
  # avant la première ligne : savoir qu'on a douze dossiers devant soi ou sept cents ne se
  # déduit pas d'un numéro de dernière page, et c'est ce qui décide si on lit ou si on filtre.
  Pagination = Data.define(:current_page, :total_pages, :total)
end
