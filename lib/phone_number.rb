# frozen_string_literal: true

# Normalisation E.164 des numéros de téléphone français. Fonctions pures, sans dépendance :
# le besoin est borné aux numéros d'administrations françaises, et une gem de plan de
# numérotation mondial serait payée pour ce qu'on n'en utilise pas. Le prix de ce choix est
# double et assumé — la table des préfixes ultramarins est tenue à la main, et
# l'attribuabilité n'est pas vérifiée : « +33 1 99 99 99 99 » a la bonne forme et n'est
# attribué à personne.
module PhoneNumber
  # Forme finale acceptée en base. Bornes E.164 : indicatif compris, un numéro ne dépasse
  # pas quinze chiffres.
  E164_FORMAT = /\A\+\d{8,15}\z/

  # La règle métropolitaine « on remplace le 0 par +33 » produirait +33262… là où le numéro
  # est +262 262…. Fixes et mobiles ne partagent pas leur préfixe, d'où deux séries par
  # territoire. Les collectivités du Pacifique (+687, +689, +681) et Saint-Pierre-et-Miquelon
  # (+508) relèvent de plans distincts — six ou huit chiffres, sans zéro initial : elles ne
  # ressemblent pas à un numéro métropolitain et se saisissent en forme internationale.
  OVERSEAS_PREFIXES = {
    "262" => "+262", "263" => "+262", "692" => "+262", "693" => "+262", # Réunion
    "269" => "+262", "639" => "+262",                                   # Mayotte
    "590" => "+590", "690" => "+590", "691" => "+590",                  # Guadeloupe, Saint-Martin, Saint-Barthélemy
    "594" => "+594", "694" => "+594",                                   # Guyane
    "596" => "+596", "696" => "+596", "697" => "+596"                   # Martinique
  }.freeze

  # Séparateurs de saisie : espaces (insécables compris), points, tirets, parenthèses.
  SEPARATORS = /[[:space:].\-()]/

  # Indicatif national des numéros imprimés en forme internationale — « +33 (0)1 42 … ».
  # Il se retire avant les séparateurs : sinon les parenthèses tombent d'abord et il reste
  # un 0 collé à l'indicatif.
  TRUNK_CODE = "(0)"

  # Un numéro national français : le zéro initial suivi de neuf chiffres.
  NATIONAL_FORMAT = /\A0\d{9}\z/

  module_function

  # Rend la forme E.164 quand elle est déductible, et la valeur nettoyée sinon — jamais nil
  # pour une saisie non vide. C'est la validation appelante qui rejette ce qui n'a pas pu
  # être normalisé : effacer ici perdrait la donnée sans que le producteur le sache.
  def normalize(raw)
    return nil if raw.blank?

    cleaned = raw.gsub(TRUNK_CODE, "").gsub(SEPARATORS, "").sub(/\A00/, "+")
    return cleaned unless cleaned.match?(NATIONAL_FORMAT)

    national = cleaned.delete_prefix("0")
    "#{OVERSEAS_PREFIXES.fetch(national[0, 3], "+33")}#{national}"
  end
end
