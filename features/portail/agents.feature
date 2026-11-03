# language: fr
Fonctionnalité: Les agents de la structure
  En tant qu'administrateur local
  Afin de savoir qui a accès au portail dans mon organisation
  Je veux consulter les agents de ma structure

  Contexte:
    Étant donné un agent rattaché à une organisation
    Et ProConnect est prêt à l'authentifier
    Et l'API amont nomme le flux "CERTDC" "Certificat de décès électronique"

  # Ses habilitations ne restreignent pas la liste. Une habilitation sur un flux auquel la
  # structure n'est pas abonnée est signalée, pas masquée.
  Scénario: L'administrateur local consulte les agents de sa structure
    Étant donné il est administrateur local habilité sur le seul flux "CERTDC"
    Et un collègue membre habilité sur le flux "HORS_ABONNEMENT"
    Et il s'est connecté
    Quand il ouvre les agents depuis le menu
    Alors les agents listés sont :
      | Agent         | Rôle                 | Flux habilités                            | Dernière connexion |
      | BERNARD Alice | Membre               | HORS_ABONNEMENT Non abonné                | Jamais             |
      | MARTIN Alex   | Administrateur local | Certificat de décès électronique – CERTDC | à sa connexion     |

  Scénario: Le membre n'a pas accès aux agents
    Étant donné il est membre habilité sur le seul flux "CERTDC"
    Et il s'est connecté
    Alors il ne voit pas les agents dans le menu
    Quand il ouvre directement l'adresse des agents
    Alors il obtient une page introuvable
