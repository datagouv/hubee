# frozen_string_literal: true

module Portail
  # Ce qu'une démarche présente à l'écran, quelle que soit sa forme. Les champs arrivent de
  # l'amont incomplets — une date jamais renseignée, un demandeur absent du paquet — et le
  # portail les traite tous pareil : une méthode par champ, qui porte son repli. Laissés aux
  # gabarits, ces replis deviennent des ternaires recopiés, et le prochain écran en oubliera un.
  #
  # Partagé entre la forme liste et la forme détail plutôt que recopié : les deux types portent
  # déjà les mêmes champs communs, leur affichage doit rester en parité de la même façon.
  #
  # `data_stream_code` n'a délibérément pas de méthode ici : rien n'y manque jamais et rien n'y
  # est à mettre en forme. Son absence est un choix, pas un oubli.
  module DeliveryDisplay
    # Ce qu'on écrit là où l'amont n'a rien à dire. Un tiret cadratin, pas un vide : une cellule
    # blanche se lit comme une colonne cassée.
    MISSING = "—"

    def display_state = I18n.t("portail.deliveries.states.#{state}")

    def display_transmitted_at = display_time(transmitted_at)

    def display_updated_at = display_time(updated_at)

    private

    def display_time(value) = value ? I18n.l(value, format: :short) : MISSING
  end
end
