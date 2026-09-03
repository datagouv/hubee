# frozen_string_literal: true

module Portail
  # `total` est affiché avant la première ligne : il ne se déduit pas d'un numéro de page.
  Pagination = Data.define(:current_page, :total_pages, :total)
end
