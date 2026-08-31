# frozen_string_literal: true

module Portail
  # Ce qu'une démarche présente à l'écran. Les champs arrivent de l'amont incomplets — une date
  # jamais renseignée, un demandeur absent du paquet — et le portail les traite tous pareil :
  # une méthode par champ, qui porte son repli. Laissés aux gabarits, ces replis deviennent des
  # ternaires recopiés, et le prochain écran en oubliera un.
  #
  # Un helper et non un mixin sur les modèles : à terme la démarche sera un ::Delivery
  # ActiveRecord, et un modèle AR dans `::` ne peut pas porter de présentation propre à
  # ::Portail. Un helper est indifférent au type qu'on lui passe — il fonctionne sur les Data
  # d'aujourd'hui, sur l'AR de demain, et sur les deux pendant la bascule.
  #
  # C'est aussi ce qui garde la forme liste et la forme détail en parité : une seule fonction
  # sert les deux, il n'y a plus rien qui puisse diverger.
  module DeliveriesHelper
    # Ce qu'on écrit là où l'amont n'a rien à dire. Un tiret cadratin, pas un vide : une cellule
    # blanche se lit comme une colonne cassée.
    MISSING = "—"

    # `default:` et non un libellé obligatoire : la liste des états appartient à l'amont, qui
    # peut en ajouter un sans nous prévenir. Sans repli, l'agent lirait « translation missing »
    # en clair dans le tableau.
    def delivery_state(delivery) = t("portail.deliveries.states.#{delivery.state}", default: MISSING)

    def delivery_transmitted_at(delivery) = delivery_time(delivery.transmitted_at)

    def delivery_updated_at(delivery) = delivery_time(delivery.updated_at)

    # Le demandeur suit la même règle que les dates : la ligne s'affiche toujours, avec son
    # repli quand l'amont n'en sert pas. La masquer ferait disparaître une information sans
    # dire qu'elle manque.
    def delivery_applicant(delivery) = delivery.applicant&.full_name.presence || MISSING

    private

    def delivery_time(value) = value ? l(value, format: :short) : MISSING
  end
end
