# frozen_string_literal: true

module Portail
  class Delivery
    # L'organisation destinataire, telle que l'amont la sert : le couple qui l'identifie dans le
    # modèle V2.
    Recipient = Data.define(:siret, :insee_code)
  end
end
