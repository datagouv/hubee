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
| `internal:agents:update` | corriger l'adresse et la civilité, modifier ou retirer un rattachement |
| `internal:agents:destroy` | supprimer un agent |

Un droit n'en implique aucun autre : supprimer un agent exige `destroy`, même pour un client qui
détient `update`.

**Imputation des écritures** : une trace nomme le client (`api_client`, `api_client_uid`), la
requête (`request_id`) et, sous `declared_actor`, la personne qui a agi **telle que le client la
déclare** dans l'en-tête `X-Actor-Id`. La trace se suffit ainsi : retrouver l'admin national n'exige
pas les journaux d'admin-portal, dont rien ne garantit qu'ils soient conservés aussi longtemps que les
traces (un an).

- **Valeur** : l'identifiant **stable** de la personne dans le système appelant, jamais son adresse :
  c'est une donnée personnelle de moins dans les traces, et un identifiant qui ne change pas avec
  l'adresse. De 1 à 255 caractères parmi les lettres ASCII sans accent, les chiffres et `.`, `_`, `:`,
  `@`, `-` (`\A[A-Za-z0-9._:@-]{1,255}\z`). Rien n'est nettoyé ni tronqué : une valeur hors de ce
  format est refusée, jamais corrigée.
- **Obligatoire** pour corriger un agent, modifier ou retirer un rattachement et supprimer un agent :
  absent, vide ou blanc, 400 `missing_actor` ; hors format, 400 `invalid_actor`. Rien n'est écrit, aucune
  trace.
- **Facultatif** à l'enregistrement (`POST /agents`), que hub-api appelle sans personne derrière.
  Absent, la trace n'a pas de clé `declared_actor` (jamais `null`). Présent, il doit être bien formé :
  un en-tête vide est une valeur envoyée, refusée en 400 `invalid_actor`. admin-portal l'envoie aussi
  quand il enregistre un agent.
- **Traitement automatique** : un traitement sans personne derrière (job, reprise, synchronisation
  côté client) envoie un identifiant explicite du traitement, préfixé, par exemple
  `job:purge-comptes-inactifs` ; jamais un en-tête vide, ni l'identifiant d'une personne qui n'a pas
  agi. Un traitement interne à HubEE n'appelle pas l'API et n'est pas concerné.
- **Déclaré, non vérifié** : l'API ne contrôle pas que la personne existe ni qu'elle a agi. La valeur
  n'étend pas la confiance accordée au client, qui peut déjà tout modifier avec ses droits, mais elle ne
  prouve rien : elle dit qui le client affirme avoir agi.
- L'en-tête est contrôlé après le droit du client et avant la lecture du corps (voir « Ordre des
  contrôles »).

```json
{"error": "missing_actor", "message": "La demande doit désigner dans l'en-tête X-Actor-Id la personne qui agit."}
{"error": "invalid_actor", "message": "L'en-tête X-Actor-Id doit compter de 1 à 255 caractères parmi les lettres ASCII sans accent, les chiffres et . _ : @ -."}
```

admin-portal **doit** aussi envoyer un en-tête `X-Request-Id` sur chaque appel d'écriture
(enregistrement, correction, modification ou retrait d'un rattachement, suppression) : il relie la
trace à la requête précise dans les journaux d'admin-portal. L'identifiant reçu est conservé tel quel
une fois retirés les caractères autres que lettres ASCII sans accent, chiffres, `-`, `_` et `@`, et
tronqué à 255 caractères ; il est renvoyé dans l'en-tête `X-Request-Id` de la réponse. Un en-tête que
ce nettoyage vide entièrement (`éà`, par exemple) donne un identifiant **vide**, pas un UUID. Sans
en-tête, ou avec un en-tête vide ou blanc, le serveur génère un UUID, que seule la réponse fait
connaître au client. Dans les deux cas, la trace ne se rattache à aucune requête des journaux
d'admin-portal. Envoyer un identifiant déjà nettoyé (un UUID, par exemple) garantit que la trace porte
exactement la valeur journalisée.

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
| `email` | oui | adresse de l'agent, sans distinction de casse : c'est elle que la connexion ProConnect retrouve. 254 caractères au plus |
| `first_name`, `last_name` | oui | fournis à l'enregistrement, puis réécrits par ProConnect à chaque connexion : aucune opération de l'API ne les modifie. Pour un agent déjà connu, exigés mais ignorés |
| `civility` | non | `mr` ou `ms` |
| `send_invitation` | non | `true` ou `false` JSON, `false` si absent : demande l'invitation de l'agent. Toute autre valeur (`"true"`, `1`, `null`, `""`, une liste…) est refusée (422). Lu dans le corps JSON seul : passé dans l'URL ou un formulaire, il est ignoré. La réponse ne change pas |
| `membership.siret` | oui | 14 chiffres |
| `membership.insee_code` | oui | le **code guichet** de l'organisation. Avec le SIRET, il la désigne sans ambiguïté, même quand plusieurs organisations partagent un SIRET. C'est son code INSEE, que le référentiel V1 appelle code de branche |
| `membership.role` | oui | `member` ou `local_administrator`, jamais déduit d'une valeur par défaut |
| `membership.job_title` | non | 255 caractères au plus ; une chaîne vide ou blanche vaut absence (la fonction n'est pas renseignée) |
| `membership.phone_number`, `membership.mobile_phone_number` | non | format E.164 (`+33123456789`) ; un numéro national français est mis en forme, tout autre numéro mal formé est refusé |
| `membership.data_stream_codes` | oui | une liste de chaînes, toujours fournie : une liste absente, `null`, un élément `null` ou toute autre forme sont refusés. Au moins un code pour un `member` ; une liste vide (`[]`) donne à un `local_administrator` l'accès à tous les flux de son organisation (hub-api l'envoie ainsi pour l'administrateur local déclaré à l'abonnement). Un code compte de 1 à 100 caractères, accents compris, sans aucun espacement (espace insécable comprise), une fois retirés les espaces en bord (`" CERTDC"` vaut `CERTDC`) ; il est un identifiant opaque : les doublons exacts sont retirés, la casse n'est jamais changée (`CERTDC` et `certdc` sont deux codes). 100 codes distincts au plus (51 codes en production au 26/10/2026). Chaque code doit être connu de hub-api sous ce code exact (une reconnaissance vaut une heure) : un seul code inconnu refuse tout l'appel, et chaque code inconnu est cité dans son motif. Un code mal formé est refusé avant toute vérification : tant qu'il en reste un, hub-api n'est interrogé sur aucun code, et les codes inconnus ne sont cités qu'une fois les codes mal formés corrigés. Les codes sont vérifiés même quand le référentiel des organisations ne répond pas, dans l'ordre transmis, jusqu'à la première panne de hub-api : les suivants ne sont examinés qu'au prochain appel |
| `source_info` | non | au premier niveau, à côté de l'enveloppe `agent` (il décrit l'appel, pas l'agent) ; placé dans `agent`, il est ignoré. Un objet aux seules clés facultatives `import` (`true` ou `false` JSON), `job_id` et `report_id` (entier JSON, sans borne, ou `null`) ; `{}` est admis. Toute autre forme (`null`, une chaîne, une clé inconnue, un `import` qui n'est pas un booléen, un id qui n'est pas un entier, même `3.0`…) est refusée (422). Lu dans le corps JSON seul, comme `send_invitation`. Seulement tracé : la réponse ne change pas |

L'invitation part en différé, après l'enregistrement, et seulement quand l'appel crée l'agent et demande
l'invitation (`send_invitation: true`). Elle ne part ni sur un rejeu, ni pour un agent déjà connu rattaché à
une nouvelle organisation, ni sur un refus ; la réponse n'en dépend pas, même si l'envoi échoue ensuite.

**201** : l'état enregistré, pas l'état demandé (pour un agent connu ailleurs, l'identité
retenue). `id` désigne l'agent dans les opérations suivantes, `membership.id` le rattachement
dans les routes `/agents/:agent_id/memberships/:id` ; l'identifiant ProConnect n'est jamais exposé.
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
| 400 | en-tête `X-Actor-Id` présent mais hors format, vide compris (facultatif ici, voir « Imputation des écritures ») | `{"error": "invalid_actor", "message": "…"}` |
| 401 | jeton absent, inconnu, expiré ou révoqué | `{"error": "invalid_token", "message": "…"}` |
| 403 | client sans le droit `internal:agents:create` | `{"error": "forbidden", "message": "…"}` |
| 404 | autre méthode que `GET` ou `POST` sur `/agents` | `{"error": "not_found", "message": "…"}` |
| 409 | agent déjà rattaché à cette organisation, pour **tout** rejeu, identique ou non : rien n'est modifié, et l'état enregistré n'est pas renvoyé | motif sur `email` |
| 409 | agent déjà rattaché à ce SIRET sous un autre code guichet (un seul rattachement par SIRET) | motif sur `membership.insee_code` |
| 422 | champ manquant ou invalide | motif sur chaque champ concerné |
| 422 | organisation inconnue du référentiel V1 | motif sur `membership.siret` |
| 422 | code de flux inconnu de hub-api | un motif par code inconnu sur `membership.data_stream_codes`, qui le cite |
| 503 | référentiel V1 (hub-api) injoignable ou incohérent, pour l'organisation comme pour un code de flux : réessayable, sans en-tête `Retry-After` | `{"error": "service_unavailable", "message": "…"}` |

Chaque écriture laisse sa trace (`agent.created` si l'agent est créé, `membership.created` ; les
traces des autres opérations sont décrites plus bas, « Traces des modifications ») : le
client appelant (nom et uid), la requête, l'acteur déclaré (`declared_actor`, seulement si
`X-Actor-Id` est envoyé), l'adresse, l'organisation, le rôle et les habilitations ;
`agent.created` porte en plus `send_invitation`, sa valeur effective.
Un `source_info` fourni est repris tel quel sous cette clé dans `agent.created` et `membership.created` ;
absent, la clé n'y figure pas.
Une invitation remise laisse `agent.invited` sur l'agent, écrit par le job après l'envoi : mêmes
métadonnées que `agent.created`, `declared_actor` compris, sans le rôle, les habilitations, `send_invitation` ni `source_info`. Le `send_invitation`
de `agent.created` dit la demande, pas l'envoi : une invitation demandée sans `agent.invited` n'a pas été remise.
L'identifiant de la requête est celui que le client envoie dans `X-Request-Id` (255 caractères au plus,
lettres, chiffres, `-`, `_` et `@`), à défaut un UUID généré par le serveur : il sert à recouper les
journaux, pas à prouver l'origine d'un appel.

### Représentation d'un agent

Même corps pour un élément de la liste, la consultation et la réponse à la correction d'un agent.

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
  `memberships` ici, et seul à sa modification. `data_stream_codes` est vide pour un administrateur
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

### Corriger l'adresse et la civilité

```http
PATCH /api/internal/v1/agents/:id  # droit internal:agents:update
X-Actor-Id: admin-national-42      # obligatoire
```

```json
{"agent": {"email": "alice.dupont@ville.fr", "civility": "ms"}}
```

| Champ | Règle |
|-------|-------|
| `email` | comme à l'enregistrement : espaces en bord retirés, mis en minuscules, au format d'une adresse, 254 caractères au plus ; ne peut pas être vidé ni valoir `null`. Une adresse déjà portée par un autre agent est refusée (409) |
| `civility` | `mr` ou `ms` ; `null` ou `""` l'efface |

- **Mise à jour partielle** : une clé absente ne change rien. Seuls `email` et `civility` se
  corrigent. `first_name`, `last_name` et toute autre clé sont ignorés, sans erreur : ProConnect
  réécrit le prénom et le nom à chaque connexion, et avant la première une faute se corrige d'elle-même.
- Une valeur qui n'est pas une chaîne (liste, objet, nombre, booléen) est refusée (422) sur son
  champ, jamais écartée en silence.
- **Enveloppe** : 400 `missing_agent` seulement quand `agent` est absent ou n'est pas un objet JSON
  (`null`, une chaîne, une liste). Un objet vide, ou qui ne porte que des clés ignorées, est une demande
  valable : 200, l'état enregistré, rien n'est écrit. L'enveloppe est lue dans le corps JSON seul :
  passée dans l'URL ou un formulaire, elle est absente.
- **Aucun changement effectif** (mêmes valeurs après normalisation, par exemple la même adresse
  dans une autre casse) : 200, rien n'est écrit, aucune trace.
- **Changement d'adresse** : l'adresse est ce que la connexion ProConnect retrouve, donc l'agent
  devra se connecter avec la nouvelle (la connexion avec l'ancienne est refusée) ; `has_signed_in`
  reste vrai. L'API ne touche pas aux sessions : dès la requête suivante de l'agent, le portail
  ferme toute session dont l'adresse n'est plus la sienne, y compris une session ouverte avec
  l'ancienne adresse par une connexion en cours au moment du changement. Aucune invitation n'est
  envoyée.
- **Piège de support** : une adresse changée par erreur se corrige sur **cette** fiche, par un nouvel
  appel de correction : c'est elle qui porte les rattachements. Si la personne s'est déjà connectée
  (`has_signed_in` vrai), enregistrer une nouvelle fiche pour l'ancienne adresse ne lui rend pas
  l'accès : la fiche corrigée par erreur garde son identifiant ProConnect, que la connexion cherche en
  premier, et l'adresse de cette fiche ne correspond plus ; la personne est refusée à la connexion tant
  que cette fiche existe.
- Le 409 vaut aussi quand un appel simultané prend l'adresse entre le contrôle et l'écriture.

**200** : la représentation de l'agent, l'état enregistré.

| Statut | Quand | Corps |
|--------|-------|-------|
| 400 | en-tête `X-Actor-Id` absent, vide ou blanc | `{"error": "missing_actor", "message": "…"}` |
| 400 | en-tête `X-Actor-Id` hors format | `{"error": "invalid_actor", "message": "…"}` |
| 400 | enveloppe `agent` absente ou qui n'est pas un objet | `{"error": "missing_agent", "message": "…"}` |
| 404 | agent inconnu | `{"error": "not_found", "message": "…"}` |
| 409 | adresse déjà portée par un autre agent | `{"email": ["désigne déjà un autre agent"]}` |
| 422 | adresse vide (`{"email": ["doit être rempli(e)"]}`) ou mal formée (`["n'est pas valide"]`), civilité hors liste (`{"civility": ["n'est pas inclus(e) dans la liste"]}`), valeur qui n'est pas une chaîne | motif sur chaque champ concerné, tous à la fois |

Le statut est celui du motif le plus fort : le 409 l'emporte sur le 422. Un refus n'écrit rien,
ni modification, ni trace.

### Modifier un rattachement

```http
PATCH /api/internal/v1/agents/:agent_id/memberships/:id  # droit internal:agents:update
X-Actor-Id: admin-national-42                            # obligatoire
```

```json
{"membership": {"role": "local_administrator", "data_stream_codes": [], "all_data_streams": true}}
```

Le rattachement est cherché **parmi ceux de l'agent** : celui d'un autre agent est introuvable (404).

| Champ | Règle |
|-------|-------|
| `role` | `member` ou `local_administrator` ; ne peut pas être vidé |
| `job_title` | 255 caractères au plus ; `null` ou une chaîne vide ou blanche l'efface ; une valeur qui n'est pas une chaîne est refusée |
| `phone_number`, `mobile_phone_number` | mêmes règles qu'à l'enregistrement (E.164, un numéro national français est mis en forme) ; `null` ou `""` l'efface |
| `data_stream_codes` | **remplace** la liste. Mêmes règles qu'à l'enregistrement (liste de chaînes, 100 codes distincts au plus, format d'un code, doublons exacts retirés, `null` et toute autre forme refusés). Absent, il garde la liste actuelle |
| `all_data_streams` | pas un champ du rattachement : confirme qu'un administrateur local aura accès à **tous** les flux (voir ci-dessous). Seul le booléen JSON `true` confirme ; `false` vaut absence ; toute autre valeur (`"true"`, `1`, `null`, une liste…) est refusée. N'apparaît ni dans la réponse ni dans la trace |

- **Mise à jour partielle** : une clé absente ne change rien. L'organisation (`siret`, `insee_code`)
  ne se modifie pas : présente dans l'enveloppe, quelle que soit sa valeur, elle est refusée (422) sur
  son champ, `["ne se modifie pas : retirez le rattachement puis ajoutez-en un par POST /agents"]`.
  Pour en changer, on retire le rattachement puis on en ajoute un par `POST /agents`. Toute autre clé
  est ignorée, sans erreur.
- **Habilitations** : seuls les codes **ajoutés** sont vérifiés auprès de hub-api (un motif par code
  inconnu, 503 si hub-api est injoignable) ; ceux déjà accordés ne sont pas revérifiés, pour qu'un
  code disparu du référentiel ne bloque pas la correction d'un autre champ. Seul l'écart s'écrit : une
  habilitation conservée garde sa ligne.
- **« Au moins un code pour un membre »** se juge sur l'**état résultant** : passer un
  administrateur local sans code à `member` sans fournir de code est refusé, comme vider la liste d'un
  membre. Un membre promu administrateur local sans `data_stream_codes` garde ses codes : ils bornent
  son accès tant qu'il en a ; `[]` **avec** `"all_data_streams": true` lui donne l'accès à tous les
  flux de son organisation (voir ci-dessous). La règle est jugée à nouveau au moment de l'écriture :
  si une modification simultanée du même rattachement la rend fausse, la demande est refusée (422,
  même motif) sans rien écrire.
- **Accès à tous les flux, confirmé** : décocher le dernier flux d'un administrateur local lui
  donnerait accès à **tous** les flux, soit plus qu'avant. Quand l'**état résultant** est
  « administrateur local avec une liste vide » et que l'état actuel ne l'est pas déjà (administrateur
  local restreint vidé, membre promu avec `[]`, membre sans code promu sans `data_stream_codes`), la
  demande doit porter `"all_data_streams": true` ; sinon 422 sur `data_stream_codes`. Un rattachement
  déjà dans cet état n'a rien à confirmer, et `true` y est accepté (un rejeu répond 200 sans rien
  écrire). `true` est refusé (422 sur `all_data_streams`) quand l'état résultant n'est pas celui-là
  (membre, ou liste non vide). Comme « au moins un code pour un membre », la règle est jugée à nouveau
  au moment de l'écriture : un code accordé entre-temps à un administrateur local qui n'en avait pas
  fait refuser une liste vide envoyée sans le drapeau. L'enregistrement (`POST /agents`) n'est pas
  concerné : `[]` y reste l'expression explicite de « tous les flux ».
- Un administrateur local est soumis au second facteur dès sa requête suivante sur le portail.
- **Enveloppe** : 400 `missing_membership` seulement quand `membership` est absent ou n'est pas un
  objet JSON ; un objet vide ou sans clé reconnue est valable, 200 sans rien écrire. Lue dans le
  corps JSON seul, comme `agent`. Une valeur qui n'est pas une chaîne pour `role`, `job_title` ou un
  numéro est refusée (422) sur son champ.
- **Aucun changement effectif** : 200, rien n'est écrit, aucune trace.

**200** : le rattachement seul, sous sa représentation (pas l'agent).

| Statut | Quand | Corps |
|--------|-------|-------|
| 400 | en-tête `X-Actor-Id` absent, vide ou blanc | `{"error": "missing_actor", "message": "…"}` |
| 400 | en-tête `X-Actor-Id` hors format | `{"error": "invalid_actor", "message": "…"}` |
| 400 | enveloppe `membership` absente ou qui n'est pas un objet | `{"error": "missing_membership", "message": "…"}` |
| 404 | agent inconnu, rattachement inconnu ou d'un autre agent | `{"error": "not_found", "message": "…"}` |
| 422 | champ invalide, `siret` ou `insee_code` présent, code de flux invalide, membre sans code, accès à tous les flux non confirmé, drapeau `all_data_streams` invalide ou hors de son emploi | motif sur chaque champ concerné |
| 422 | code de flux ajouté inconnu de hub-api | un motif par code inconnu sur `data_stream_codes`, qui le cite |
| 503 | hub-api injoignable pendant la vérification des codes ajoutés : réessayable | `{"error": "service_unavailable", "message": "…"}` |

Motifs sur `data_stream_codes` : `["doit être une liste de codes"]`, `["ne peut pas compter plus de
100 codes distincts"]`, `["doit compter au moins un
code pour un membre"]`, `["contient un code invalide : « CERT DC »"]`, `["contient un code de flux
inconnu du référentiel : « INCONNU »"]`, `["donnerait accès à tous les flux de l'organisation :
envoyez all_data_streams à true pour le confirmer"]`. Motifs sur `all_data_streams` : `["doit être le
booléen JSON true ou false"]`, `["ne s'emploie qu'avec une liste vide pour un administrateur
local"]`. Une demande refusée reçoit **tous** ses motifs à la fois ;
le 503 n'est signalé que s'il n'y a aucun autre motif. Un refus n'écrit rien, trace comprise.

### Retirer un rattachement

```http
DELETE /api/internal/v1/agents/:agent_id/memberships/:id  # droit internal:agents:update
X-Actor-Id: admin-national-42                             # obligatoire
```

**204**, sans corps. Le retrait relève du droit `update` : il corrige l'agent. Les habilitations et
les sessions ouvertes du rattachement disparaissent avec lui : l'accès tombe à la requête suivante de
l'agent, sans effet sur ses autres rattachements. Le dernier rattachement peut être retiré : l'agent
reste, sans accès ; le supprimer est l'objet de la suppression de l'agent. L'organisation, elle,
reste.

Erreurs : 400 `missing_actor` ou `invalid_actor` pour un en-tête `X-Actor-Id` absent ou hors format
(voir « Imputation des écritures ») ; 404 pour un agent ou un rattachement inconnu, ou un rattachement
d'un autre agent ; 401 et 403 ; voir « Ordre des contrôles ». Un refus n'écrit rien.

### Supprimer un agent

```http
DELETE /api/internal/v1/agents/:id  # droit internal:agents:destroy
X-Actor-Id: admin-national-42       # obligatoire
```

**204**, sans corps. L'agent, ses rattachements, leurs habilitations et leurs sessions ouvertes sont
supprimés : l'accès tombe à la requête suivante, et plus aucune connexion n'est possible. Les
organisations restent, d'autres agents s'y rattachent. Rien n'est demandé ni changé chez hub-api. Les
traces antérieures de l'agent sont conservées. Un agent supprimé peut être enregistré de nouveau par
`POST /agents` : c'est un nouvel agent, avec un nouvel `id`.

Erreurs : 400 `missing_actor` ou `invalid_actor` pour un en-tête `X-Actor-Id` absent ou hors format
(voir « Imputation des écritures ») ; 404 pour un agent inconnu, 401, 403 (le droit `update` ne suffit
pas) ; voir « Ordre des contrôles ». Un refus n'écrit rien.

### Ordre des contrôles

Les sept opérations sur les agents suivent le même ordre, et le premier contrôle qui refuse donne la
réponse :

| Ordre | Contrôle | Refus |
|-------|----------|-------|
| 1 | jeton | 401 |
| 2 | droit du client | 403, même sur une ressource inconnue, même si le corps est illisible ou l'en-tête d'acteur absent |
| 3 | en-tête `X-Actor-Id` | 400 `missing_actor` ou `invalid_actor`, même sur une ressource inconnue, même si le corps est illisible |
| 4 | corps lisible | 400 `bad_request`, même sur une ressource inconnue |
| 5 | ressource désignée par l'URL (agent, rattachement) | 404 |
| 6 | enveloppe présente (`agent` ou `membership`) | 400 `missing_agent` ou `missing_membership` |
| 7 | motifs de la demande : champs, paramètres, référentiel, conflits | 409, sinon 422, tous les motifs à la fois |
| 8 | référentiel joignable | 503, seulement sans aucun motif |

Les étapes 3, 5 et 6 ne concernent que les opérations qui les portent (une lecture n'a pas d'en-tête
d'acteur, l'enregistrement ne refuse que celui qui est mal formé et n'a pas de ressource à retrouver,
une lecture n'a pas d'enveloppe). Des paramètres d'URL mal formés sont refusés
(400) avant tout contrôle, jeton compris. Les erreurs sans champ ont la forme commune à l'API,
`{"error": "<code>", "message": "…"}` ; celles qui portent sur un champ, `{"<champ>": ["<motif>"]}`.
L'espace interne est fermé par défaut : une action qui n'aurait pas vérifié le droit du client
échoue au lieu de répondre.

### Traces des modifications

Chaque écriture effective laisse sa trace dans la même transaction : sans elle, rien n'est écrit.
Aucune trace pour un refus ni pour un appel sans effet. Les métadonnées reprennent celles de
l'enregistrement (`api_client`, `api_client_uid`, `request_id`), l'acteur déclaré (`declared_actor`,
toujours présent ici puisque l'en-tête est obligatoire) et de quoi lire la trace seule, après la
suppression de l'agent : son adresse, et pour un rattachement `siret` et `insee_code`. `declared_actor`
dit qui le client affirme avoir agi ; `request_id` relie la trace à la requête dans les journaux
d'admin-portal (voir « Imputation des écritures »).

| Type | Sujet | Quand | Métadonnées en plus |
|------|-------|-------|---------------------|
| `agent.updated` | l'agent | adresse ou civilité effectivement modifiée | `changes` ; `email` est la nouvelle adresse |
| `membership.updated` | le rattachement | rattachement effectivement modifié | `changes`, `siret`, `insee_code` |
| `membership.deleted` | le rattachement | retrait | `siret`, `insee_code`, `role`, `data_stream_codes` (triés) au moment du retrait |
| `agent.deleted` | l'agent | suppression | `memberships` : un élément par rattachement supprimé (`siret`, `insee_code`, `role`, `data_stream_codes` triés), classés par SIRET puis code guichet |

`changes` donne, pour chaque champ **effectivement modifié**, `{"champ": [avant, après]}`, données
personnelles comprises (adresse, civilité, fonction, téléphones). Les habilitations y figurent sous
`data_stream_codes`, en deux listes triées. Les champs reçus sans changement n'y sont pas.

```json
{
  "api_client": "admin-portal",
  "api_client_uid": "…",
  "request_id": "…",
  "declared_actor": "admin-national-42",
  "email": "alice.martin@ville.fr",
  "siret": "21750056000016",
  "insee_code": "75056",
  "changes": {
    "role": ["member", "local_administrator"],
    "data_stream_codes": [["CERTDC"], []]
  }
}
```

Les traces de création restent telles quelles, sans nom ni téléphone : une valeur qu'aucune trace de
modification ne mentionne vient de la création. Le prénom et le nom, que ProConnect réécrit à chaque
connexion sans laisser de trace, ne permettent pas de reconstituer l'historique du nom.

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
