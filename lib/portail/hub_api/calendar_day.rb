# frozen_string_literal: true

module Portail
  module HubAPI
    # Un jour civil AAAA-MM-JJ venu de l'URL, refusé en InvalidRequest avant tout appel.
    module CalendarDay
      # Le siècle borne les années absurdes. Pas de `Date.iso8601` : il accepterait aussi les
      # écritures ordinale et compacte, et lève hors Date::Error au-delà de 128 caractères.
      FORMAT = /\A((?:19|20)\d{2})-(\d{2})-(\d{2})\z/

      class << self
        def parse!(value)
          parts = parts_of(value)
          raise InvalidRequest, "Unreadable date #{value.inspect} (expected YYYY-MM-DD)" unless parts && Date.valid_date?(*parts)

          Date.new(*parts)
        end

        private

        # Année, mois et jour en entiers, ou nil hors de la forme attendue.
        def parts_of(value)
          return unless (match = FORMAT.match(value))

          match.captures.map(&:to_i)
        end
      end
    end
  end
end
