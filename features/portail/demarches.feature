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

  # Chaque état est une page : une navigation, pas un onglet.
  Scénario: L'agent passe d'un état à l'autre par le menu latéral
    Étant donné l'API amont sert aussi une démarche traitée pour son organisation
    Et il s'est connecté
    Quand il filtre sur l'état "Traitée"
    Alors la liste est celle de l'état "Traitée"

  # L'amont ne borne que sur l'organisation : le refus par flux est le nôtre.
  Scénario: Une démarche hors habilitation reste fermée
    Étant donné l'API amont sert aussi une démarche sur un flux non habilité
    Et il s'est connecté
    Quand il ouvre directement cette démarche
    Alors il obtient une page introuvable, sans que le dossier lui soit montré

  # Le filtre et le tri sont portés par l'URL : la page se recharge et se partage telle quelle.
  Scénario: L'agent restreint la liste à un flux
    Étant donné il est habilité sur le flux "AEC"
    Et l'API amont sert aussi une démarche "DGS-AEC-0000000000002-01" sur le flux "AEC"
    Et il s'est connecté
    Quand il filtre sur le flux "AEC"
    Alors il ne voit que la démarche "DGS-AEC-0000000000002-01"

  Scénario: L'agent restreint la liste à plusieurs flux à la fois
    Étant donné il est habilité sur le flux "AEC"
    Et il est habilité sur le flux "DEMO"
    Et l'API amont sert aussi une démarche "DGS-AEC-0000000000002-01" sur le flux "AEC"
    Et l'API amont sert aussi une démarche "DGS-DEMO-0000000000004-01" sur le flux "DEMO"
    Et il s'est connecté
    Quand il filtre sur les flux "AEC, CERTDC"
    Alors il ne voit que les démarches "DGS-AEC-0000000000002-01, DGS-CERTDC-0000000000001-01"

  Scénario: L'agent restreint la liste à une période de transmission
    Étant donné l'API amont sert aussi une démarche "DGS-CERTDC-0000000000003-01" transmise le "2026-08-20"
    Et il s'est connecté
    Quand il filtre sur les démarches transmises jusqu'au "2026-08-31"
    Alors il ne voit que la démarche "DGS-CERTDC-0000000000003-01"

  # Les plus récentes d'abord par défaut : un clic sur l'en-tête inverse l'ordre.
  Scénario: L'agent inverse l'ordre de transmission
    Étant donné l'API amont sert aussi une démarche "DGS-CERTDC-0000000000003-01" transmise le "2026-08-20"
    Et il s'est connecté
    Quand il trie par « Transmise le »
    Alors les démarches sont listées dans l'ordre "DGS-CERTDC-0000000000003-01, DGS-CERTDC-0000000000001-01"

  # Sans habilitation nommée, les flux proposés viennent des abonnements de la structure : seuls
  # ceux en lecture via le portail comptent, et jamais ceux d'une autre organisation du même SIRET.
  Scénario: L'administrateur local sans habilitation filtre sur les flux reçus par le portail
    Étant donné il est administrateur local sans habilitation
    Et l'API amont sert à sa structure des abonnements de toutes natures
    Et il s'est connecté
    Alors le filtre propose les flux "AEC, CERTDC"
    Quand il filtre sur le flux "AEC"
    Alors il ne voit que la démarche "DGS-AEC-0000000000002-01"
