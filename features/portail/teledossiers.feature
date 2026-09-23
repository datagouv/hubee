# language: fr
Fonctionnalité: Les télédossiers de l'organisation
  En tant qu'agent connecté
  Afin de suivre les dossiers de ma structure
  Je veux consulter les télédossiers de mon organisation et ouvrir leur détail

  Contexte:
    Étant donné un agent rattaché à une organisation
    Et il est habilité sur le flux "CERTDC"
    Et ProConnect est prêt à l'authentifier
    Et l'API amont sert un télédossier pour son organisation

  Scénario: L'agent connecté arrive sur les télédossiers de sa structure
    Étant donné il s'est connecté
    Alors il voit le télédossier "DGS-CERTDC-0000000000001-01" dans la liste

  Scénario: L'agent ouvre le détail d'un télédossier
    Étant donné il s'est connecté
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Alors il voit le détail du télédossier, demandeur compris
    Et il voit le flux nommé "Certificat de décès électronique"

  Scénario: L'agent fait avancer un télédossier depuis son détail
    Étant donné il s'est connecté
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Alors il ne peut pas clore le télédossier
    Quand il finalise le traitement du télédossier
    Alors il voit le télédossier au statut "Traité"
    Et l'historique porte le changement signé "Alex MARTIN"

  Scénario: L'agent joint une pièce en faisant avancer un télédossier
    Étant donné il s'est connecté
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Et il finalise le traitement du télédossier en joignant "decision.pdf"
    Alors il voit le télédossier au statut "Traité"
    Et l'historique porte "Alex MARTIN a déposé une pièce"
    Et la pièce ajoutée "decision.pdf" figure au détail

  Scénario: Une pièce refusée par l'antivirus laisse l'état intact
    Étant donné il s'est connecté
    Et l'analyse antivirus refusera le prochain fichier
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Et il finalise le traitement du télédossier en joignant "decision.pdf"
    Alors il voit que la pièce a été refusée par l'antivirus
    Et il ne voit pas le télédossier au statut "Traité"

  Scénario: Le détail inventorie les pièces et déroule l'historique
    Étant donné il s'est connecté
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Alors il voit l'inventaire des pièces et l'historique

  # L'intitulé vient des abonnements de la structure ; le code reste, c'est lui que le support
  # connaît. Les autres scénarios n'en posent aucun : le code seul suffit à identifier la ligne.
  Scénario: L'agent lit la démarche d'un télédossier sans connaître son code
    Étant donné l'API amont nomme le flux "CERTDC" "Certificat de décès électronique"
    Et il s'est connecté
    Alors il voit le télédossier "DGS-CERTDC-0000000000001-01" sous la démarche "Certificat de décès électronique – CERTDC"
    Et le filtre propose les flux "Certificat de décès électronique – CERTDC"

  # Chaque état est une page : une navigation, pas un onglet.
  Scénario: L'agent passe d'un état à l'autre par le menu latéral
    Étant donné l'API amont sert aussi un télédossier traité pour son organisation
    Et il s'est connecté
    Quand il filtre sur l'état "Traité"
    Alors la liste est celle de l'état "Traité"

  # L'amont ne borne que sur l'organisation : le refus par flux est le nôtre.
  Scénario: Un télédossier hors habilitation reste fermé
    Étant donné l'API amont sert aussi un télédossier sur un flux non habilité
    Et il s'est connecté
    Quand il ouvre directement ce télédossier
    Alors il obtient une page introuvable, sans que le dossier lui soit montré

  # HubEE supervise cet état : ni dans le menu, ni par son adresse.
  Scénario: Un télédossier en erreur d'intégration reste fermée
    Étant donné l'API amont sert aussi un télédossier en erreur d'intégration pour son organisation
    Et il s'est connecté
    Alors le menu des états ne propose pas "Erreur d'intégration"
    Quand il ouvre directement ce télédossier
    Alors il obtient une page introuvable, sans que le dossier lui soit montré

  # Le filtre et le tri sont portés par l'URL : la page se recharge et se partage telle quelle.
  Scénario: L'agent restreint la liste à un flux
    Étant donné il est habilité sur le flux "AEC"
    Et l'API amont sert aussi un télédossier "DGS-AEC-0000000000002-01" sur le flux "AEC"
    Et il s'est connecté
    Quand il filtre sur le flux "AEC"
    Alors il ne voit que le télédossier "DGS-AEC-0000000000002-01"

  Scénario: L'agent restreint la liste à plusieurs flux à la fois
    Étant donné il est habilité sur le flux "AEC"
    Et il est habilité sur le flux "DEMO"
    Et l'API amont sert aussi un télédossier "DGS-AEC-0000000000002-01" sur le flux "AEC"
    Et l'API amont sert aussi un télédossier "DGS-DEMO-0000000000004-01" sur le flux "DEMO"
    Et il s'est connecté
    Quand il filtre sur les flux "AEC, CERTDC"
    Alors il ne voit que les télédossiers "DGS-AEC-0000000000002-01, DGS-CERTDC-0000000000001-01"

  # Le numéro suffit, complet ou tronqué : c'est ainsi qu'il circule entre les agents.
  Scénario: L'agent retrouve un télédossier par un fragment de son numéro
    Étant donné l'API amont sert aussi un télédossier "DGS-CERTDC-0000000000005-01" sur le flux "CERTDC"
    Et il s'est connecté
    Quand il cherche le numéro "0000000000005"
    Alors il ne voit que le télédossier "DGS-CERTDC-0000000000005-01"

  # Même périmètre qu'en liste : un numéro hors habilitation ne renvoie rien, sans confirmer le dossier.
  Scénario: Un numéro hors habilitation ne renvoie rien
    Étant donné l'API amont sert aussi un télédossier sur un flux non habilité
    Et il s'est connecté
    Quand il cherche le numéro "DGS-AEC-0000000000002-01"
    Alors aucun télédossier ne correspond à ses critères

  Scénario: L'agent restreint la liste à une période de transmission
    Étant donné l'API amont sert aussi un télédossier "DGS-CERTDC-0000000000003-01" transmis le "2026-08-20"
    Et il s'est connecté
    Quand il filtre sur les télédossiers transmis jusqu'au "2026-08-31"
    Alors il ne voit que le télédossier "DGS-CERTDC-0000000000003-01"

  # Les plus récentes d'abord par défaut : un clic sur l'en-tête inverse l'ordre.
  Scénario: L'agent inverse l'ordre de transmission
    Étant donné l'API amont sert aussi un télédossier "DGS-CERTDC-0000000000003-01" transmis le "2026-08-20"
    Et il s'est connecté
    Quand il trie par « Transmis le »
    Alors les télédossiers sont listés dans l'ordre "DGS-CERTDC-0000000000003-01, DGS-CERTDC-0000000000001-01"

  # Sans habilitation nommée, les flux proposés viennent des abonnements de la structure : seuls
  # ceux en lecture via le portail comptent, et jamais ceux d'une autre organisation du même SIRET.
  Scénario: L'administrateur local sans habilitation filtre sur les flux reçus par le portail
    Étant donné il est administrateur local sans habilitation
    Et l'API amont sert à sa structure des abonnements de toutes natures
    Et il s'est connecté
    Alors le filtre propose les flux "AEC, CERTDC"
    Quand il filtre sur le flux "AEC"
    Alors il ne voit que le télédossier "DGS-AEC-0000000000002-01"

  Scénario: L'agent télécharge une pièce reçue depuis le détail
    Étant donné il s'est connecté
    Quand il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Et il télécharge la pièce "certificat.pdf"
    Alors il obtient le fichier "certificat.pdf" en pièce jointe

  # L'adresse seule, sans passer par le détail, à travers toute la chaîne.
  Scénario: L'agent récupère une pièce reçue par son adresse
    Étant donné il s'est connecté
    Quand il récupère directement la pièce "certificat.pdf" du télédossier "DGS-CERTDC-0000000000001-01"
    Alors il obtient le fichier "certificat.pdf" en pièce jointe

  # La trace écrite à l'amont revient dans l'historique que lit le portail : le type d'événement
  # qu'écrit la gem doit bien retomber sur la phrase du téléchargement, et pas sur le repli.
  Scénario: La récupération d'une pièce s'inscrit à l'historique du télédossier
    Étant donné il s'est connecté
    Quand il récupère directement la pièce "certificat.pdf" du télédossier "DGS-CERTDC-0000000000001-01"
    Et il se rend sur l'accueil
    Et il ouvre le télédossier "DGS-CERTDC-0000000000001-01"
    Alors l'historique porte "Alex MARTIN a téléchargé une pièce"

  # Le dossier a atteint le plafond d'événements de l'amont : la récupération ne peut plus y être
  # inscrite, donc la pièce n'est pas remise.
  Scénario: Une pièce dont la récupération ne peut pas être tracée n'est pas remise
    Étant donné l'historique du télédossier "DGS-CERTDC-0000000000001-01" est saturé
    Et il s'est connecté
    Quand il récupère directement la pièce "certificat.pdf" du télédossier "DGS-CERTDC-0000000000001-01"
    Alors il voit que la pièce ne peut pas être remise

  Scénario: Une pièce hors habilitation reste fermée
    Étant donné l'API amont sert aussi un télédossier sur un flux non habilité
    Et il s'est connecté
    Quand il récupère directement la pièce "certificat.pdf" de ce télédossier
    Alors il obtient une page introuvable, sans que le dossier lui soit montré
