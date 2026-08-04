# frozen_string_literal: true

module Portail
  # Combien de temps une session du portail reste utilisable. Deux bornes indépendantes.
  #
  # La borne absolue est alignée sur la session ProConnect, de douze heures : plus courte,
  # elle serait sans effet — un clic réauthentifie en silence tant que celle-ci vit, et
  # `max-age`, qui corrigerait ça, n'est pas implémenté côté ProConnect. Ce que ces bornes
  # garantissent : le rattachement et le niveau sont réévalués à chaque reprise.
  #
  # Vit ici et non sur le modèle : c'est une décision du portail, révisable sans que la
  # table change. Deux appelants dans deux couches — le concern qui décide à chaque
  # requête, le job qui ramasse les orphelines.
  module SessionLifetime
    IDLE = 30.minutes
    ABSOLUTE = 12.hours

    def self.expired?(provider_session)
      Time.current > provider_session.created_at + ABSOLUTE ||
        Time.current > provider_session.updated_at + IDLE
    end
  end
end
