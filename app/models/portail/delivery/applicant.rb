# frozen_string_literal: true

module Portail
  class Delivery
    # Le demandeur, réduit à ce que le portail affiche : l'adresse électronique servie en amont
    # n'est pas reprise, rien ne l'affiche.
    Applicant = Data.define(:first_name, :last_name) do
      # Les deux moitiés sont facultatives en amont.
      def full_name = [first_name, last_name].compact_blank.join(" ")
    end
  end
end
