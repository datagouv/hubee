# language: fr
Fonctionnalité: Un agent créé par l'API entre sur le portail
  C'est le critère d'acceptation qui traverse les deux modules : la voie
  d'entrée débouche réellement sur le portail.

  Scénario: L'agent créé par un système authentifié se connecte ensuite
    Étant donné un agent créé par l'API avec son rattachement
    Et que ProConnect est prêt à l'authentifier
    Quand il se rend sur l'accueil
    Et qu'il clique sur "S'identifier avec ProConnect"
    Alors il est connecté au portail
