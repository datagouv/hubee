# frozen_string_literal: true

module Portail
  # Une organisation telle que l'amont la sert : le couple qui l'identifie dans le modèle V2.
  # Homonyme de ::Organization, le modèle ActiveRecord : dans `module Portail`, un `Organization`
  # nu résout vers cette constante-ci.
  Organization = Data.define(:siret, :insee_code)
end
