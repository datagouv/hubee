# frozen_string_literal: true

module Portail
  # Le demandeur d'une démarche, réduit à ce que le portail affiche. L'adresse électronique
  # servie en amont n'est pas reprise : rien ne l'affiche, et la porter obligerait à la
  # protéger partout où la démarche circule.
  Applicant = Data.define(:first_name, :last_name) do
    # Les deux moitiés sont facultatives en amont : un demandeur sans prénom ne doit pas
    # produire un nom qui commence par une espace.
    def full_name = [first_name, last_name].compact_blank.join(" ")
  end
end
