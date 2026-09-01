# language: fr
Fonctionnalité: Les démarches de l'organisation
  En tant qu'agent connecté
  Afin de suivre les dossiers de ma structure
  Je veux consulter les démarches de mon organisation et ouvrir leur détail

  Contexte:
    Étant donné un agent rattaché à une organisation
    Et il est habilité sur le flux "CERTDC"
    Et ProConnect est prêt à l'authentifier
    Et l'API amont sert une démarche pour son organisation

  Scénario: L'agent connecté arrive sur les démarches de sa structure
    Étant donné il s'est connecté
    Alors il voit la démarche "DGS-CERTDC-0000000000001-01" dans la liste

  Scénario: L'agent ouvre le détail d'une démarche
    Étant donné il s'est connecté
    Quand il ouvre la démarche "DGS-CERTDC-0000000000001-01"
    Alors il voit le détail de la démarche, demandeur compris

  Scénario: Le détail inventorie les pièces et déroule l'historique
    Étant donné il s'est connecté
    Quand il ouvre la démarche "DGS-CERTDC-0000000000001-01"
    Alors il voit l'inventaire des pièces et l'historique

  # Le filtre de statut de l'amont n'accepte qu'une valeur : chaque état est une page, et
  # c'est bien une navigation — pas un basculement d'onglet dans la page.
  Scénario: L'agent passe d'un état à l'autre par le menu latéral
    Étant donné l'API amont sert aussi une démarche traitée pour son organisation
    Et il s'est connecté
    Quand il filtre sur l'état "Traitée"
    Alors la liste est celle de l'état "Traitée"

  # L'habilitation par flux est la nôtre à refuser : l'API amont ne borne que sur
  # l'organisation, elle servirait ce dossier sans broncher.
  Scénario: Une démarche hors habilitation reste fermée
    Étant donné l'API amont sert aussi une démarche sur un flux non habilité
    Et il s'est connecté
    Quand il ouvre directement cette démarche
    Alors il est renvoyé à la liste sans que le dossier lui soit montré
