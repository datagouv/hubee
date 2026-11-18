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

  # Les identifiants ne s'affichent jamais en entier : de quoi les reconnaître, et la copie. Leur
  # consultation est très sensible : le clic passe d'abord par une réauthentification ProConnect,
  # puis la consultation part d'elle-même au retour.
  @javascript
  Scénario: L'administrateur local copie le secret d'un abonnement API sans le voir
    Étant donné il est administrateur local habilité sur le seul flux "CERTDC"
    Et l'API amont sert les identifiants de l'abonnement "DEMO_API"
    Et il s'est connecté
    Quand il ouvre l'abonnement "Démonstration par l'API – DEMO_API" depuis la liste
    Et il clique sur "Obtenir les identifiants"
    Alors il voit les identifiants masqués, jamais en entier
    Quand il clique sur "Copier le secret client"
    Alors le secret entier est dans son presse-papiers
    Et il lit "Copié dans le presse-papiers."
    Et le message est espacé du champ comme le prévoit le DSFR
    Et le bouton "Copier le secret client" confirme la copie, puis revient à son libellé
    Quand il clique sur "Copier l'identifiant client"
    Alors l'identifiant client entier est dans son presse-papiers
    Et il ne lit qu'une fois "Copié dans le presse-papiers."

  @javascript
  Scénario: La copie échoue, l'administrateur local est prévenu
    Étant donné il est administrateur local habilité sur le seul flux "CERTDC"
    Et l'API amont sert les identifiants de l'abonnement "DEMO_API"
    Et il s'est connecté
    Quand il ouvre l'abonnement "Démonstration par l'API – DEMO_API" depuis la liste
    Et il clique sur "Obtenir les identifiants"
    # La réauthentification recharge la page : la copie ne peut être refusée qu'une fois les
    # identifiants affichés.
    Et il lit "Pour votre sécurité, seuls les 4 premiers caractères sont affichés."
    Et son navigateur refuse la copie
    Et il clique sur "Copier le secret client"
    Alors il lit "La copie n'a pas fonctionné. Réessayez ; si le problème persiste, écrivez à support@hubee.numerique.gouv.fr."
    Et le message est espacé du champ comme le prévoit le DSFR
    Et il ne lit pas "Copié dans le presse-papiers."
