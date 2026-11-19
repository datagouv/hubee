# Hubee V2 - API REST

**Version**: 1.2.0 | **Base URL**: `/api`, suivi de l'espace et de sa version (`/api/internal/v1`) :
voir « Versionnage ». `/api/v1` est l'ébauche gelée décrite plus bas.

## Philosophie

- **RESTful** + **JSON** (Jbuilder) + **Bearer Auth** + **Rails Scaffold Style**
- **Flat Responses** : index = array direct, show = objet direct
- **Nesting Policy** :
  - ❌ **has_many** : jamais nester (évite explosion payload)
  - ✅ **belongs_to** : peut être nesté (1 objet, évite requêtes multiples)
  - Exception historique : `attachments` nested dans `data_packages` (has_many)
  - Exception de l'espace interne : les `memberships` d'un agent, imbriqués dans sa représentation
    (voir « Représentation d'un agent »)
- **Pagination** : Headers HTTP (X-Page, X-Total), body reste array direct
- **Autorisations** : (r) = read, (w) = write
- **IDs API** : UUIDs v4 partout (primary keys), SIRET conservé comme attribut métier des Organizations

## Versionnage

La version majeure fait partie du chemin, après l'espace : `/api/<espace>/v<N>/…`, servi par le
module `API::<Espace>::V<N>` (par exemple `/api/internal/v1/…` et `API::Internal::V1`). Une
version qui n'existe pas répond la 404 d'une URL inconnue. Une spec de routage refuse toute route
sous `/api` qui n'a pas cette forme, hors de ce qui reste commun à toutes les versions.

Dans une version, on n'apporte que des changements compatibles. Une rupture crée la version
suivante.

Chaque nouvelle version duplique le code de la précédente : les contrôleurs, base de l'espace
comprise, les forms, les interactors et leurs étapes, les policies, les vues, les helpers s'il y en
a, et leurs specs.

Restent communs à toutes les versions, sans numéro :

- `API::BaseController`, `API::ErrorsController` et la 404 de toute URL inconnue sous `/api` ;
- `POST /api/oauth/token` et `GET /api/ping` ;
- `API::HubAPI`, les modèles et les jobs ;
- les messages `api.errors.*` ;
- les droits d'un client OAuth : un droit vaut pour toutes les versions.

Les endpoints gelés décrits plus bas, sous `/api/v1`, ne suivent pas encore cette règle. Ce `v1`
est celui de l'ébauche de l'API V2 : il n'a rien à voir avec l'API V1 en production.

## Authentification & Autorisations

**Bearer Token** : `Authorization: Bearer <token>`, seul emplacement lu. Un jeton passé dans l'URL
(`access_token`, `bearer_token`) ou dans le corps est ignoré : la requête reçoit 401, comme sans
jeton. Un proxy journalise l'URL, donc le jeton qui y serait (RFC 6750 § 2.3).
- Délivrance : `POST /api/oauth/token`, OAuth2 `client_credentials`, identifiants du client dans le
  corps ou en HTTP Basic ; jeton valable 2 heures, stocké haché, communiqué une seule fois
- Droits **(r)** / **(w)** : prévus pour les endpoints gelés, non appliqués

## Espace interne (`/api/internal`)

Réservé aux systèmes internes de la plateforme, dont hub-api, jamais exposé à l'API publique.
Avec `/api/ping` et l'émission du jeton, c'est la seule partie de l'API en service ; les
endpoints décrits plus bas restent gelés.

**Authentification** : jeton OAuth2 `client_credentials` (`POST /api/oauth/token`), demandé
**sans `scope`**, puis `Authorization: Bearer <token>`. Un `scope`, même le nom d'un droit, fait
refuser le jeton (400 `invalid_scope`).

Les refus de `POST /api/oauth/token` suivent OAuth2 : `{"error": "<code>", "error_description": "…"}`.

| Statut | `error` | Quand |
|--------|---------|-------|
| 400 | `invalid_request` | `grant_type` absent |
| 400 | `unsupported_grant_type` | `grant_type` autre que `client_credentials` |
| 400 | `invalid_scope` | un `scope` demandé |
| 401 | `invalid_client` | client inconnu, secret faux ou absent, sans distinction |

Un corps JSON illisible y reçoit le 400 général, `{"error": "bad_request", "message": "La requête est mal formée."}`.

**Droits** : accordés au client, opération par opération (voir `docs/RUNBOOK.md`). Ils ne
passent pas par le jeton : ils sont lus à chaque appel, et un client sans le droit reçoit 403 `forbidden`.

| Droit | Opérations |
|-------|------------|
| `internal:agents:create` | enregistrer un agent |
| `internal:agents:read` | lister et rechercher les agents, consulter un agent |

### Enregistrer un agent

```http
POST /api/internal/v1/agents        # droit internal:agents:create
```

Crée l'agent s'il est inconnu, le rattache s'il est déjà connu (même adresse) pour une autre
organisation. Son identité n'est alors pas modifiée : c'est ProConnect qui la rafraîchit à la
connexion. C'est aussi la seule voie pour **ajouter un rattachement** à un agent connu :
`first_name` et `last_name` restent exigés, puis ignorés (reprendre ceux de l'agent). L'organisation
est vérifiée au référentiel V1 (organisation de type SI) à chaque appel, même connue de la V2, puis
prise en compte si elle est nouvelle. Un seul rattachement par appel : un agent de deux organisations
donne deux appels.

```json
{
  "agent": {
    "email": "alice.martin@ville.fr",
    "first_name": "Alice",
    "last_name": "Martin",
    "civility": "ms",
    "send_invitation": true,
    "membership": {
      "siret": "21750056000016",
      "insee_code": "75056",
      "role": "member",
      "job_title": "Officier d'état civil",
      "phone_number": "+33123456789",
      "mobile_phone_number": "+33612345678",
      "data_stream_codes": ["CERTDC"]
    }
  },
  "source_info": {"import": true, "job_id": 123, "report_id": 45}
}
```

| Champ | Obligatoire | Règle |
|-------|-------------|-------|
| `email` | oui | adresse de l'agent, sans distinction de casse : c'est elle que la connexion ProConnect retrouve |
| `first_name`, `last_name` | oui | fournis à l'enregistrement, puis réécrits par ProConnect à chaque connexion : aucune opération de l'API ne les modifie. Pour un agent déjà connu, exigés mais ignorés |
| `civility` | non | `mr` ou `ms` |
| `send_invitation` | non | `true` ou `false` JSON, `false` si absent : demande l'invitation de l'agent. Toute autre valeur (`"true"`, `1`, `null`, `""`, une liste…) est refusée (422). Lu dans le corps JSON seul : passé dans l'URL ou un formulaire, il est ignoré. La réponse ne change pas |
| `membership.siret` | oui | 14 chiffres |
| `membership.insee_code` | oui | le **code guichet** de l'organisation. Avec le SIRET, il la désigne sans ambiguïté, même quand plusieurs organisations partagent un SIRET. C'est son code INSEE, que le référentiel V1 appelle code de branche |
| `membership.role` | oui | `member` ou `local_administrator`, jamais déduit d'une valeur par défaut |
| `membership.job_title` | non | 255 caractères au plus |
| `membership.phone_number`, `membership.mobile_phone_number` | non | format E.164 (`+33123456789`) ; un numéro national français est mis en forme, tout autre numéro mal formé est refusé |
| `membership.data_stream_codes` | oui | une liste de chaînes, toujours fournie : une liste absente, `null`, un élément `null` ou toute autre forme sont refusés. Au moins un code pour un `member` ; une liste vide (`[]`) donne à un `local_administrator` l'accès à tous les flux de son organisation (hub-api l'envoie ainsi pour l'administrateur local déclaré à l'abonnement). Un code compte de 1 à 100 caractères, accents compris, sans aucun espacement (espace insécable comprise), une fois retirés les espaces en bord (`" CERTDC"` vaut `CERTDC`) ; il est un identifiant opaque : les doublons exacts sont retirés, la casse n'est jamais changée (`CERTDC` et `certdc` sont deux codes). 100 codes distincts au plus (51 codes en production au 26/10/2026). Chaque code doit être connu de hub-api sous ce code exact (une reconnaissance vaut une heure) : un seul code inconnu refuse tout l'appel, et chaque code inconnu est cité dans son motif. Un code mal formé est refusé avant toute vérification : tant qu'il en reste un, hub-api n'est interrogé sur aucun code, et les codes inconnus ne sont cités qu'une fois les codes mal formés corrigés. Les codes sont vérifiés même quand le référentiel des organisations ne répond pas, dans l'ordre transmis, jusqu'à la première panne de hub-api : les suivants ne sont examinés qu'au prochain appel |
| `source_info` | non | au premier niveau, à côté de l'enveloppe `agent` (il décrit l'appel, pas l'agent) ; placé dans `agent`, il est ignoré. Un objet aux seules clés facultatives `import` (`true` ou `false` JSON), `job_id` et `report_id` (entier JSON, sans borne, ou `null`) ; `{}` est admis. Toute autre forme (`null`, une chaîne, une clé inconnue, un `import` qui n'est pas un booléen, un id qui n'est pas un entier, même `3.0`…) est refusée (422). Lu dans le corps JSON seul, comme `send_invitation`. Seulement tracé : la réponse ne change pas |

L'invitation part en différé, après l'enregistrement, et seulement quand l'appel crée l'agent et demande
l'invitation (`send_invitation: true`). Elle ne part ni sur un rejeu, ni pour un agent déjà connu rattaché à
une nouvelle organisation, ni sur un refus ; la réponse n'en dépend pas, même si l'envoi échoue ensuite.

**201** : l'état enregistré, pas l'état demandé (pour un agent connu ailleurs, l'identité
retenue). `id` désigne l'agent dans les opérations suivantes, `membership.id` le rattachement ;
l'identifiant ProConnect n'est jamais exposé.
Le rattachement a la même représentation que dans la liste des agents.

```json
{
  "id": "0199…",
  "email": "alice.martin@ville.fr",
  "first_name": "Alice",
  "last_name": "Martin",
  "civility": "ms",
  "membership": {
    "id": "0199…",
    "siret": "21750056000016",
    "insee_code": "75056",
    "role": "member",
    "job_title": "Officier d'état civil",
    "phone_number": "+33123456789",
    "mobile_phone_number": "+33612345678",
    "data_stream_codes": ["CERTDC"],
    "last_signed_in_at": null
  }
}
```

**Erreurs.** Les motifs qui portent sur un champ reprennent l'imbrication de la demande, sans
l'enveloppe `agent` : un motif sur un champ du rattachement apparaît sous `membership`. Un motif sur
`source_info`, hors de l'enveloppe, apparaît au même niveau que ceux de l'agent. Les
erreurs sans champ ont la forme commune à l'API, `{"error": "<code>", "message": "…"}` (section
« Erreurs », plus bas). Les messages sont en français.

```json
{
  "email": ["désigne un agent déjà rattaché à cette organisation"],
  "membership": {"phone_number": ["n'est pas valide"]}
}
```

Une demande refusée reçoit **tous** ses motifs à la fois, chacun sur son champ. Le statut est
celui du motif le plus fort : un conflit (409) l'emporte sur une demande invalide (422). Un
référentiel indisponible (503) n'est signalé que s'il n'y a aucun autre motif. Un refus n'écrit
rien, ni agent, ni organisation, ni rattachement, ni trace.

Les contrôles se suivent dans l'ordre commun à toutes les opérations sur les agents (voir « Ordre
des contrôles »).

| Statut | Quand | Corps |
|--------|-------|-------|
| 400 | corps illisible (JSON mal formé) | `{"error": "bad_request", "message": "…"}` |
| 400 | enveloppe `agent` absente | `{"error": "missing_agent", "message": "…"}` |
| 401 | jeton absent, inconnu, expiré ou révoqué | `{"error": "invalid_token", "message": "…"}` |
| 403 | client sans le droit `internal:agents:create` | `{"error": "forbidden", "message": "…"}` |
| 404 | autre méthode que `GET` ou `POST` sur `/agents` | `{"error": "not_found", "message": "…"}` |
| 409 | agent déjà rattaché à cette organisation, pour **tout** rejeu, identique ou non : rien n'est modifié, et l'état enregistré n'est pas renvoyé | motif sur `email` |
| 409 | agent déjà rattaché à ce SIRET sous un autre code guichet (un seul rattachement par SIRET) | motif sur `membership.insee_code` |
| 422 | champ manquant ou invalide | motif sur chaque champ concerné |
| 422 | organisation inconnue du référentiel V1 | motif sur `membership.siret` |
| 422 | code de flux inconnu de hub-api | un motif par code inconnu sur `membership.data_stream_codes`, qui le cite |
| 503 | référentiel V1 (hub-api) injoignable ou incohérent, pour l'organisation comme pour un code de flux : réessayable, sans en-tête `Retry-After` | `{"error": "service_unavailable", "message": "…"}` |

Chaque écriture laisse sa trace (`agent.created` si l'agent est créé, `membership.created`) : le
client appelant (nom et uid), la requête, l'adresse, l'organisation, le rôle et les habilitations ;
`agent.created` porte en plus `send_invitation`, sa valeur effective.
Un `source_info` fourni est repris tel quel sous cette clé dans `agent.created` et `membership.created` ;
absent, la clé n'y figure pas.
Une invitation remise laisse `agent.invited` sur l'agent, écrit par le job après l'envoi : mêmes
métadonnées que `agent.created`, sans le rôle, les habilitations, `send_invitation` ni `source_info`. Le `send_invitation`
de `agent.created` dit la demande, pas l'envoi : une invitation demandée sans `agent.invited` n'a pas été remise.
L'identifiant de la requête est celui que le client envoie dans `X-Request-Id` (255 caractères au plus,
lettres, chiffres, `-`, `_` et `@`), à défaut un UUID généré par le serveur : il sert à recouper les
journaux, pas à prouver l'origine d'un appel.

### Représentation d'un agent

Même corps pour un élément de la liste et la consultation d'un agent.

```json
{
  "id": "0199…",
  "email": "alice.martin@ville.fr",
  "first_name": "Alice",
  "last_name": "Martin",
  "civility": "ms",
  "has_signed_in": true,
  "created_at": "2026-11-02T10:12:00.000+01:00",
  "memberships": [
    {
      "id": "0199…",
      "siret": "21750056000016",
      "insee_code": "75056",
      "role": "member",
      "job_title": "Officier d'état civil",
      "phone_number": "+33123456789",
      "mobile_phone_number": "+33612345678",
      "data_stream_codes": ["CERTDC"],
      "last_signed_in_at": "2026-11-10T09:00:00.000+01:00"
    }
  ]
}
```

- `has_signed_in` : l'agent s'est déjà connecté par ProConnect. L'identifiant ProConnect lui-même
  n'est jamais exposé.
- Les dates sont en ISO 8601, dans le fuseau de l'application (Paris), avec leur décalage (`+01:00`
  l'hiver, `+02:00` l'été), jamais en `Z`. `last_signed_in_at` vaut `null` tant que l'agent ne s'est
  jamais connecté sous ce rattachement.
- `first_name` et `last_name` sont ceux de ProConnect : l'API ne les modifie pas.
- `memberships` est **imbriqué**, en écart assumé à la « Nesting Policy » : un agent a peu de
  rattachements (au plus un par SIRET), et lister les agents avec leurs rattachements et leurs rôles
  ne doit pas coûter un appel par agent. Ils sont rendus dans l'ordre de leur création ; la liste est
  vide pour un agent sans rattachement.
- Un rattachement a la même représentation partout : sous `membership` à l'enregistrement, dans
  `memberships` ici. `data_stream_codes` est vide pour un administrateur
  local qui a accès à tous les flux ; il n'est pas ordonné. Le nom de l'organisation n'y figure pas :
  il vit au référentiel V1.

### Lister et rechercher les agents

```http
GET /api/internal/v1/agents        # droit internal:agents:read
GET /api/internal/v1/agents?siret=21750056000016&insee_code=75056&role=member&search=alice%20mar&page=1&per_page=50
```

Tous les agents, ordonnés par adresse, sans appel au référentiel. Chaque critère présent restreint
la liste ; sans aucun critère, c'est tout le stock, paginé.

| Paramètre | Règle |
|-----------|-------|
| `siret` | 14 chiffres : les agents qui ont un rattachement sur ce SIRET |
| `insee_code` | le code guichet, **seulement avec `siret`** (422 sinon) : restreint à ce rattachement |
| `role` | `member` ou `local_administrator` |
| `search` | recherche texte, 255 caractères au plus, voir ci-dessous |
| `page` | entier de 1 à 1000, défaut 1 |
| `per_page` | entier de 1 à 100, défaut 50 |

- Les paramètres se lisent dans la **chaîne de requête** seule : un corps de requête n'est pas lu.
- Un critère vide, ou réduit à des espaces, vaut un critère absent. Un paramètre inconnu est ignoré.
  Un critère qui n'est pas une chaîne (`role[]=member`, `siret[a]=…`) est refusé (422) sur son
  champ : `["doit être une chaîne, pas une liste ni un objet"]` ; l'écarter rendrait tout le stock.
- `siret`, `insee_code` et `role` désignent le **même** rattachement : un agent membre sur un SIRET
  et administrateur sur un autre ne répond pas à « administrateur de ce SIRET ».
- Un critère ne réduit que la liste : chaque agent est rendu avec **tous** ses rattachements.
- Un paramètre invalide refuse la demande (422), tous les motifs à la fois, à plat par paramètre :
  `{"siret": ["doit comporter 14 chiffres"]}`, `{"insee_code": ["ne s'emploie qu'avec un SIRET"]}`,
  `{"role": ["n'est pas inclus(e) dans la liste"]}`, `{"search": ["est trop long (pas plus de 255
  caractères)"]}`.

**`search`** : la saisie entière, espaces en bord retirés (elle n'est pas découpée en mots), doit
être le **début** de l'un de ces champs, sans distinction de casse : l'adresse, le prénom, le nom,
« prénom nom », « nom prénom ». Le tiret et l'espace s'équivalent, des deux côtés. Les accents sont
distingués. `%`, `_` et `\` s'entendent tels quels, sans valeur de joker.

| Saisie | Trouve | Ne trouve pas |
|--------|--------|---------------|
| `alice mar` | Alice Martin (« prénom nom ») | |
| `martin al` | Alice Martin (« nom prénom ») | |
| `de la fontaine` | Jean De La Fontaine (le nom) | |
| `marie claire` | Marie-Claire Durand (tiret et espace équivalents) | |
| `marie-claire` | Marie-Claire Durand | |
| `alice.mar` | alice.martin@ville.fr (l'adresse) | |
| `ALICE` | Alice Martin (sans distinction de casse) | |
| `claire` | | Marie-Claire Durand : ce n'est le début d'aucun champ |
| `ville.fr` | | alice.martin@ville.fr : le début seulement, pas le domaine |
| `alice  mar` (deux espaces) | | Alice Martin : l'espace intérieur compte |
| `elodie` | | Élodie Roux : les accents sont distingués |
| `50%` | un agent dont le prénom commence par `50%` | tous les autres : `%` n'est pas un joker |

**Pagination** : `page` (de 1 à 1000, défaut 1) et `per_page` (de 1 à 100, défaut 50), en-têtes
`X-Page`, `X-Per-Page`, `X-Total` et `X-Total-Pages` ; le corps reste le tableau d'agents. Le total
compte les agents, pas leurs rattachements. Une valeur hors de ses bornes ou qui n'est pas un entier
est refusée (422) avec son motif, comme un autre critère : `{"page": ["n'est pas un nombre"]}` (`abc`,
une liste), `["doit être un nombre entier"]` (`1.5`), `["doit être supérieur ou égal à 1"]` (`0`,
`-5`), `["doit être inférieur ou égal à 1000"]` ; de même pour `per_page`, borné à 100. Une valeur
vide vaut absence. Une page dans les bornes mais au-delà de la dernière donne une liste vide (`[]`,
en-têtes à l'appui). Les liens de l'en-tête `Link` reprennent les critères validés et `per_page`.

**200** : le tableau des agents, `[]` quand aucun ne répond. Erreurs : 401, 403, 422 (paramètre
invalide), 400 (paramètres d'URL mal formés) ; voir « Ordre des contrôles ».

### Consulter un agent

```http
GET /api/internal/v1/agents/:id    # droit internal:agents:read
```

**200** : la représentation de l'agent. **404** `not_found` pour un agent inconnu, comme pour un `id`
qui n'est pas un identifiant. Rien n'est demandé au référentiel : une lecture n'échoue pas parce que
hub-api est indisponible.

### Ordre des contrôles

Les trois opérations sur les agents suivent le même ordre, et le premier contrôle qui refuse donne la
réponse :

| Ordre | Contrôle | Refus |
|-------|----------|-------|
| 1 | jeton | 401 |
| 2 | droit du client | 403, même sur une ressource inconnue, même si le corps est illisible |
| 3 | corps lisible | 400 `bad_request`, même sur une ressource inconnue |
| 4 | ressource désignée par l'URL (agent) | 404 |
| 5 | enveloppe présente (`agent`) | 400 `missing_agent` |
| 6 | motifs de la demande : champs, paramètres, référentiel, conflits | 409, sinon 422, tous les motifs à la fois |
| 7 | référentiel joignable | 503, seulement sans aucun motif |

Les étapes 4 et 5 ne concernent que les opérations qui les portent (l'enregistrement n'a pas de
ressource à retrouver, une lecture n'a pas d'enveloppe). Des paramètres d'URL mal formés sont refusés
(400) avant tout contrôle, jeton compris. Les erreurs sans champ ont la forme commune à l'API,
`{"error": "<code>", "message": "…"}` ; celles qui portent sur un champ, `{"<champ>": ["<motif>"]}`.
L'espace interne est fermé par défaut : une action qui n'aurait pas vérifié le droit du client
échoue au lieu de répondre.

## Endpoints (Rails Scaffold Style)

**Pattern de réponse universel** :
- **index** : `[{...}, {...}]` (array direct)
- **show** : `{...}` (objet direct)
- **create/update** : `{...}` (objet créé/modifié)
- Pas de wrapper sauf `attachments` dans `data_packages`

### Organizations

```http
GET    /api/v1/organizations              # index → [{id: uuid, name, siret, created_at}, ...]
GET    /api/v1/organizations/:id          # show  → {id: uuid, name, siret, created_at}
POST   /api/v1/organizations               # (admin futur)
PUT    /api/v1/organizations/:id          # (admin futur)
DELETE /api/v1/organizations/:id          # (admin futur)
```

**Note** : `id` (UUID) est l'identifiant primaire. SIRET conservé comme attribut métier unique. Routes utilisent `:id` comme param (convention REST standard).

### Data Streams (r/w)

```http
GET    /api/v1/data_streams              # index → [{id: uuid, name, description, owner_organization: {id, name, siret, ...}, retention_days, created_at}, ...]
POST   /api/v1/data_streams         (w)  # create → {id: uuid, ...} | body: {data_stream: {name, description, owner_organization_id: uuid, retention_days}}
GET    /api/v1/data_streams/:id        # show  → {id: uuid, name, description, owner_organization: {id, name, siret, ...}, retention_days, created_at}
PUT    /api/v1/data_streams/:id   (w)  # update → {id: uuid, ...}
DELETE /api/v1/data_streams/:id   (w)  # 204 (si aucune notification existante)
```

**Notes** :
- `owner_organization` est **nested** (belongs_to) pour éviter requêtes multiples
- L'update permet de changer `owner_organization_id` (transfert de propriété du data stream entre organisations)
- `retention_days` accepte `null` (pas de limite de rétention)

### Subscriptions (r/w)

```http
GET    /api/v1/organizations/:id/subscriptions  # index (admin-only) → [{id: uuid, data_stream_id: uuid, organization: {id, name, siret}, can_read: bool, can_write: bool, created_at}, ...]
GET    /api/v1/data_streams/:id/subscriptions    # index → [{id: uuid, ..., organization: {...}, can_read: bool, can_write: bool}, ...]
POST   /api/v1/data_streams/:id/subscriptions    # create → {id: uuid, ...} | body: {subscription: {organization_id: uuid, can_read: bool, can_write: bool}}
GET    /api/v1/subscriptions/:id                 # show → {id: uuid, data_stream_id: uuid, organization: {id, name, siret}, can_read: bool, can_write: bool, created_at}
PUT    /api/v1/subscriptions/:id                 # update → {id: uuid, ...} | body: {subscription: {can_read: bool, can_write: bool}}
DELETE /api/v1/subscriptions/:id                 # 204
GET    /api/v1/data_packages/:id/subscriptions   # index → {subscriptions: [...], source: "resolver"|"notifications", delivery_criteria: {...}} + pagination headers
```

**Boolean Permissions** : `can_read` et `can_write` (au moins un doit être `true`)

**Exemples de permissions** :
```json
{"can_read": true, "can_write": false}   // Lecture seule
{"can_read": false, "can_write": true}   // Écriture seule
{"can_read": true, "can_write": true}    // Lecture et écriture
```

**Filtres par permissions** :
```http
GET /api/v1/organizations/:id/subscriptions?can_read=true           # Toutes avec can_read=true
GET /api/v1/organizations/:id/subscriptions?can_write=true          # Toutes avec can_write=true
GET /api/v1/organizations/:id/subscriptions?can_read=true&can_write=true  # Seulement lecture ET écriture
GET /api/v1/organizations/:id/subscriptions?can_read=false          # Toutes avec can_read=false (écriture seule)
GET /api/v1/organizations/:id/subscriptions?can_write=false         # Toutes avec can_write=false (lecture seule)
```

**Data Package Subscriptions** (Prévisualisation/Historique) :
```http
GET /api/v1/data_packages/:id/subscriptions
```
- **Draft package** : utilise `DeliveryCriteria::Resolver` pour prévisualiser les subscriptions ciblées
- **Transmitted/Acknowledged package** : retourne les subscriptions via les notifications existantes
- Response inclut `source` ("resolver" ou "notifications") pour indiquer la source

**Notes** :
- `organization` est **nested** (belongs_to) pour éviter requêtes multiples
- Endpoint `/organizations/:id/subscriptions` = admin-only (Feature 9: Authentication)
- CASCADE DELETE : Subscriptions supprimées automatiquement si data_stream ou organization supprimés
- Validation : au moins une permission doit être accordée (`can_read` ou `can_write` = true)
- Filtres acceptent `true`/`false` comme strings (ex: `?can_read=true`)

### Data Packages (r/w) - Exception : attachments nested

```http
GET    /api/v1/data_packages                         # index → [{id: uuid, data_stream_id: uuid, sender_organization_id: uuid, status, title, sent_at, created_at}, ...]
GET    /api/v1/data_streams/:id/data_packages      # index (producteur: tous | consommateur: notifiés uniquement)
POST   /api/v1/data_streams/:id/data_packages (w)  # create → {id: uuid, ...} | body: {data_package: {title, target_organization_ids: [uuid, ...]}}
GET    /api/v1/data_packages/:id                   # show  → {id: uuid, ..., attachments: [{id: uuid, filename, byte_size, processing_status}, ...]}
PUT    /api/v1/data_packages/:id               (w) # update → {id: uuid, ...} (changement title uniquement)
DELETE /api/v1/data_packages/:id               (w) # 204 (si aucune notification existante)
POST   /api/v1/data_packages/:id/send          (w) # {id: uuid, ...} (transitions: ready → sent, crée notifications)
```

**Filters** : `?status=draft|ready|sent|acknowledged&data_stream_id=<uuid>`
**⚠️ Exception unique** : `attachments` array nested dans le show (avec UUIDs)

**Delivery Criteria** (ciblage des notifications) :
```json
// Critères supportés
{
  "siret": "13002526500013",           // SIRET unique ou array
  "organization_id": "uuid",            // UUID organization ou array
  "subscription_id": "uuid"             // UUID subscription ou array
}

// Opérateurs logiques
{
  "_or": [                              // Union des résultats
    {"siret": "13002526500013"},
    {"organization_id": "uuid"}
  ]
}

{
  "_and": [                             // Intersection des résultats
    {"siret": "13002526500013"},
    {"organization_id": "uuid"}
  ]
}

// Critères multiples (AND implicite)
{
  "siret": "13002526500013",
  "organization_id": "uuid"             // Doit satisfaire les deux
}
```

**Limites** :
- **Max profondeur** : 2 niveaux de nesting (ex: `_or` → `_and` → leaf)
- **Max critères** : 20 critères total (comptés dans les feuilles)
- **Validation** : Structure validée à la création du data_package

### Attachments (w pour POST/DELETE, r/w pour GET)

```http
POST   /api/v1/data_packages/:id/attachments  (w)      # 202 → {id: uuid, filename, processing_status: "pending", data_package_id: uuid, created_at}
GET    /api/v1/attachments/:id                         # show → {id: uuid, filename, processing_status, byte_size, virus_scan_result, encrypted, retry_count, data_package_id: uuid, created_at}
DELETE /api/v1/attachments/:id                 (w)      # 204
GET    /api/v1/attachments/:id/download                # 302 Redirect → S3 signed URL
GET    /api/v1/data_packages/:id/attachments/download  # Download all (ZIP)
POST   /api/v1/attachments/:id/retry          (w)      # Re-enqueue si status = scan_failed/encryption_failed/upload_failed
```

**Upload** : `multipart/form-data` + `file`, `filename`, `checksum: "sha256:abc..."`
**Processing states** : `pending → scanning → encrypting → uploading → completed` (ou `*_failed`)
**Note** : `id` exposé = UUID. `data_package_id` = UUID.

### Notifications (r/w)

```http
GET    /api/v1/notifications                        # index → [{id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: uuid, status, sent_at, acknowledged_at, created_at}, ...]
GET    /api/v1/data_streams/:id/notifications     # index (filter par stream)
GET    /api/v1/notifications/:id                  # show  → {id: uuid, data_package_id: uuid, subscription_id: uuid, organization_id: uuid, status, sent_at, acknowledged_at, created_at}
POST   /api/v1/notifications/:id/acknowledge      # {id: uuid, ...} (transitions: sent → acknowledged)
```

**Filters** : `?status=pending|sent|acknowledged&data_stream_id=<uuid>`
**Note** : `id` exposé = UUID. Relations : `data_package_id` = UUID, `organization_id` = UUID.

### Users

```http
GET    /api/v1/users                         # index → [{id: uuid, email, name, created_at}, ...]
GET    /api/v1/users/:id                   # show  → {id: uuid, email, name, created_at}
GET    /api/v1/organizations/:id/users    # index (users d'une org)
GET    /api/v1/users/:id/organizations     # index (orgs d'un user : [{id: uuid, name, siret, ...}]) - pas nested
POST   /api/v1/users                         # (admin futur)
PUT    /api/v1/users/:id                   # (admin futur)
DELETE /api/v1/users/:id                   # (admin futur)
```

**Note** : `id` exposé = UUID.

## Pagination (Pagy)

**Query** : `?page=1&per_page=50` (défaut 50, max 100)
**Headers** : `X-Page`, `X-Per-Page`, `X-Total`, `X-Total-Pages`
**Body** : Array direct (pas de meta dans body)

## Erreurs

Toute erreur sous `/api` répond en JSON, jamais par une page du portail, sous la forme
`{"error": "<code>", "message": "<phrase>"}`. Le code est stable : c'est lui qu'un programme lit.
La phrase, en français, s'adresse à une personne et peut changer ; elle montre aussi que la
réponse vient de l'application, et non d'un composant placé en amont.

| Statut | `error` | `message` | Quand |
|--------|---------|-----------|-------|
| 400 | `bad_request` | La requête est mal formée. | corps JSON illisible, paramètres d'URL mal formés |
| 401 | `invalid_token` | Le jeton d'accès est absent, inconnu, expiré ou révoqué. | jeton absent, inconnu, expiré ou révoqué, sans distinction ; en-tête `WWW-Authenticate: Bearer …` |
| 404 | `not_found` | Ressource introuvable. | URL inconnue sous `/api`, ou méthode non servie ; ressource introuvable |
| 500 | `internal_server_error` | Une erreur est survenue. | erreur inattendue |

Une exception à laquelle Rails donne un autre statut (409, 422…) le garde, avec le nom de ce
statut pour code (`conflict`, `unprocessable_content`…) et la phrase de la 500. Les erreurs
propres à un endpoint sont décrites avec lui ; `POST /api/oauth/token` suit OAuth2 (`error`,
`error_description`).

Deux écarts à RFC 6750 § 3.1, acceptés : sans jeton, l'en-tête annonce quand même
`error="invalid_token"` (la RFC recommande de n'y mettre aucun code) ; les caractères non ASCII de
`error_description` y deviennent `_`.

Les endpoints gelés (`/api/v1`) prévoyaient d'autres réponses (403 sur les droits (r)/(w), 422
`{champ: […]}`, limite de débit en 429) : rien de cela n'est en service.

## Code Style & Patterns

**Voir** : `.ai/context/CODE_STYLE.md` pour :
- Patterns Jbuilder (partials, flat responses, identifiants)
- Controllers (params.expect, find_by!, error handling)
- Models (delegates, validations, associations)
- Tests (RSpec patterns, factories)

**Identifiants API** :
- Toutes les ressources : UUID v4 exposé comme `id` (primary key, généré par `gen_random_uuid()`)
- Organizations : `siret` conservé comme attribut métier unique (14 chiffres)
- Relations : Toujours par UUID (`organization_id`, `data_stream_id`, etc.)

## Workflow Exemple : Producteur → Consommateur

```bash
# Producteur (Organization UUID: <org-uuid-1>)
POST /api/v1/data_packages {data_stream_id: "<uuid>", title: "..."} → {id: "<uuid>", status: "draft"}
POST /api/v1/data_packages/<uuid>/attachments (multipart)           → {id: "<uuid>", processing_status: "pending"}
GET  /api/v1/attachments/<uuid> (polling)                           → {processing_status: "completed"}
POST /api/v1/data_packages/<uuid>/send                              → {id: "<uuid>", status: "sent"} + notifications créées

# Consommateur (Organization UUID: <org-uuid-2>)
GET  /api/v1/notifications?status=sent                              → [{id: "<uuid>", data_package_id: "<uuid>", organization_id: "<org-uuid-2>", ...}]
GET  /api/v1/data_packages/<uuid>                                   → {id: "<uuid>", sender_organization_id: "<org-uuid-1>", attachments: [{id: "<uuid>", ...}]}
GET  /api/v1/attachments/<uuid>/download                            → 302 → S3 signed URL
POST /api/v1/notifications/<uuid>/acknowledge                       → {id: "<uuid>", status: "acknowledged"}
```
