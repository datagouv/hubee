# frozen_string_literal: true

module API
  # Une organisation telle que le référentiel la sert : l'API n'en lit que le nom.
  # Homonyme de ::Organization, le modèle ActiveRecord : dans `module API`, un `Organization`
  # nu résout vers cette constante-ci.
  Organization = Data.define(:name)
end
