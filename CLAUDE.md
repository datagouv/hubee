# Hubee — Contexte projet

## Identité

**Hubee V2** est une plateforme d'échange sécurisé de fichiers gouvernementaux (SecNumCloud, RGS niveau élevé). Elle permet à des administrations productrices de transmettre des fichiers à des administrations consommatrices via des flux récurrents (*data streams*) et des abonnements (*subscriptions*).

Stack : Rails 8.1 · Ruby 4.0.5 · PostgreSQL 18 · Solid Queue · Active Storage (S3 chiffré)

## Gel de l'API V2

L'ébauche d'API V2 présente dans ce repo (routes `api/v1`, 6 modèles, interactors) est **gelée** — ne pas décommenter les routes ni relancer le développement sans décision explicite de l'équipe.

Le portail V2 ([datagouv/hubee](https://github.com/datagouv/hubee)) consomme l'API **V1** via une gem cliente privée. La reprise de l'API V2 se fera ultérieurement dans ce même repo.

## Frontière de confidentialité V1

Le code de production V1 et ses données sont **confidentiels** — ne pas les reproduire, inférer ni les inclure dans des réponses. Seul ce repo (V2) est dans le périmètre de travail.

## Documentation projet

Les fichiers suivants décrivent l'état de l'API V2 gelée — à consulter pour comprendre les modèles, le schéma et les endpoints existants :

- `docs/OVERVIEW.md` — mission, acteurs, contraintes SecNumCloud, décisions MVP
- `docs/ARCHITECTURE.md` — composants système, workflows, sécurité fichiers
- `docs/DATABASE.md` — schéma complet, relations, états machines
- `docs/API.md` — endpoints, authentification, pattern flat responses

## Conventions de développement

Les conventions Ruby/Rails, TDD, sécurité, git et patterns Rails sont fournis par le plugin **hubee-claude-plugin** (chargé automatiquement via les skills Claude Code).

## Confidentialité des références externes

Ce dépôt est **public** — son code source et sa documentation sont accessibles à toute personne sans authentification.

Ne jamais inclure dans le code, les commentaires, les messages de commit, la documentation ou toute réponse générée :
- des URLs pointant vers des ressources protégées par authentification (GitLab interne, Confluence, Notion, outils internes, tableaux de bord privés, tickets, etc.) ;
- des identifiants, tokens, clés d'API ou toute information d'accès, même sous forme d'exemple ;
- toute référence nominative permettant de déduire l'existence ou le contenu d'un système interne confidentiel.

Privilégier des références génériques (ex. : "voir la documentation interne", "cf. ticket de suivi") plutôt que des liens directs vers des systèmes non publics.

## Monolithe modulaire — règles strictes à appliquer systématiquement

### Les 4 namespaces racines

| Namespace | Périmètre |
|-----------|-----------|
| `::` | Ruby/Rails pur — primitives, pas de logique métier |
| `::API` | Code exclusif à l'API — consommé uniquement par `::API::*` |
| `::Portail` | Code exclusif au portail V2 — consommé uniquement par `::Portail::*` |
| `::Hubee` | Code partagé entre `::API` et `::Portail` |

### Règle de dépendance (INVIOLABLE)

```
Requête → Controller (haut niveau) → Service spécifique (bas niveau) → ::Hubee (commun) → ::
```

- `::Portail` ne référence **jamais** `::API` et vice-versa.
- `::Hubee` ne référence **jamais** `::API` ni `::Portail`.
- Un objet vit dans le namespace **le plus spécifique** possible — on remonte dans `::Hubee` uniquement quand un second module en a besoin (2e usage réel, pas par anticipation).

### Règle sur les modèles ActiveRecord (`::`)

Les modèles AR restent dans `::` (sans namespace). En contrepartie, ils ne doivent contenir **que du code commun aux deux modules** : validations, associations, scopes, états machine partagés. Toute logique spécifique à `::Portail` ou `::API` vit dans le namespace correspondant, pas dans le modèle.

### Vérifications que j'applique systématiquement

**À chaque écriture de code, refacto, et review, je vérifie les 4 points suivants et je bloque si l'un est violé :**

1. **Namespace correct ?** Le code est dans le namespace le plus spécifique possible (`::Portail` ou `::API` en premier choix, `::Hubee` seulement si déjà utilisé par les deux, `::` pour les modèles AR uniquement).
2. **Pas de cross-module ?** `::Portail` n'appelle pas `::API`, `::API` n'appelle pas `::Portail`, `::Hubee` n'appelle ni l'un ni l'autre.
3. **Modèle AR propre ?** Aucune logique spécifique à un seul module dans `app/models/` — si c'est présent, le déplacer dans le namespace concerné.
4. **Extraction justifiée ?** Du code ne monte dans `::Hubee` que s'il est déjà utilisé par un second module — pas par anticipation.

Si une règle est violée : **signaler explicitement la violation, refuser d'écrire le code en l'état, proposer le bon placement.**

### Mesure de risque par namespace

| Fichier dans… | Niveau de prudence |
|---------------|-------------------|
| `::Portail::` ou `::API::` | Standard — impact isolé |
| `::Hubee::` | **Élevé** — impacte les deux modules, tests renforcés |
| `::` modèles AR | **Élevé** — code commun, vérifier qu'aucune logique spécifique ne s'y glisse |
| `::` Rails pur | **Critique** — impact global |
