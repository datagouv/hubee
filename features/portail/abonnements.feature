# language: fr
Fonctionnalité: Les abonnements de la structure
  En tant qu'administrateur local
  Afin de savoir quelles démarches ma structure reçoit et par quel canal
  Je veux consulter les abonnements de mon organisation

  Contexte:
    Étant donné un agent rattaché à une organisation
    Et ProConnect est prêt à l'authentifier
    Et l'API amont sert à sa structure des abonnements de toutes natures

  # Ses habilitations ne restreignent pas la liste : elle montre tous les flux de la structure,
  # quel que soit le canal, et jamais ceux d'une autre organisation du même SIRET.
  Scénario: L'administrateur local consulte les abonnements de sa structure
    Étant donné il est administrateur local habilité sur le seul flux "CERTDC"
    Et il s'est connecté
    Quand il ouvre les abonnements depuis le menu
    Alors les abonnements listés sont :
      | Démarche                                    | Accès   | État    |
      | Actes d'état civil – AEC                    | Portail | Actif   |
      | Certificat de décès électronique – CERTDC   | Portail | Actif   |
      | Démonstration inactive – DEMO_INACTIF       | Portail | Inactif |
      | Démonstration par l'API – DEMO_API          | API     | Actif   |

  Scénario: Le membre n'a pas accès aux abonnements
    Étant donné il est membre habilité sur le seul flux "CERTDC"
    Et il s'est connecté
    Alors il ne voit pas les abonnements dans le menu
    Quand il ouvre directement l'adresse des abonnements
    Alors il obtient une page introuvable
