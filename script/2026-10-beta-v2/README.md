# Import des utilisateurs de la bêta V2 (octobre 2026)

Opération ponctuelle, non maintenue. Enrôle dans le portail V2 les utilisateurs de la bêta (~70) :
compte, rattachement à l'organisation, rôle et habilitations par démarche. Au-delà de quelques
dizaines d'utilisateurs, le collage en console ne tient plus : passer par une autre voie.

## Sources

| Fichier | Séparateur | Colonnes lues | Origine |
|---|---|---|---|
| `utilisateurs.csv` | `,` | `Nom`, `Prénom`, `Adresse e-mail`, `Organisation`, `Type Utilisateur HubEE` (les autres sont ignorées) | tableur de la bêta |
| `organisations.csv` | `,` | `Organisation`, `CompanyRegister` (SIRET), `BranchCode` (code INSEE) | tableur des organisations |
| `keycloak.csv` | `;` | `email;keycloak_id;enabled;required_actions;first_name;last_name;user_type;siret;branch_code;organization_name;unrestricted;process_code;process_status;anomalie` | export des comptes Keycloak lancé en console sur l'environnement visé (cf. ticket) |

Le rôle, le prénom et le nom viennent du tableur (prénom et nom de Keycloak s'ils sont vides),
les démarches de Keycloak, déjà croisées avec les abonnements de l'organisation par l'export.
`Type Utilisateur HubEE` : `AGT` ou `agent` → membre, `ADM_LOC`, `admin local` ou
`administrateur local` → administrateur local.

## Déroulé

1. Export Keycloak sur l'environnement visé, CSV copié depuis le terminal : seulement les lignes
   entre `-----BEGIN CSV-----` et `-----END CSV-----`, sans ces marqueurs ni les lignes qui les
   entourent (empreinte du script, compte rendu de lecture).
2. Génération, en local, sortie hors du dépôt ou sous `tmp/` :
   `ruby script/2026-10-beta-v2/generer_import.rb utilisateurs.csv organisations.csv keycloak.csv tmp/import-beta`
3. `bin/rails console --sandbox` sur l'environnement visé, coller chaque `lot-NN.txt`, relire.
4. `bin/rails console`, coller les mêmes lots. Conserver la sortie.
5. Traiter `rapport.csv` : `anomalie` (non injecté) et `avertissement` (injecté, ne verra rien).
6. Supprimer CSV et lots.

La première ligne de chaque lot affiche l'empreinte SHA-256 de `importer_agents.rb` : identique en
recette et en production si le code exécuté l'est. Le fichier doit être présent dans l'image
déployée.

## Règles

- Injecté : rôle et démarches remis à l'identique de l'entrée ; chaque changement est affiché
  (`agent créé`, `rattachement créé`, `rôle a → b`, `+ démarche`, `− démarche`). Relancer un lot
  ne change rien. L'identité d'un agent existant n'est jamais modifiée.
- Les lignes vides des tableurs sont ignorées.
- Avertissement : membre sans aucune démarche — se connecte mais ne voit rien.
- Anomalie : absent ou signalé par l'export, compte désactivé ou jamais activé, type hors
  agent / admin local, organisation divergente ou invalide, email en double, admin local dont toutes
  les démarches sont hors abonnement (il verrait tout).
- Un admin local sans démarche voit tout ; avec des démarches, seulement celles-là.
- Second facteur ProConnect obligatoire pour les admins locaux et les démarches sensibles.
