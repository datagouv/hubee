# Runbook

Gestes d'exploitation de l'application. Dépôt public : aucune valeur réelle ici.

## Clients API (OAuth2 `client_credentials`)

Les accès des systèmes clients de l'API V2 se gèrent en console Rails.

### Délivrer un accès

    app = Doorkeeper::Application.create!(name: "nom-du-client")
    app.uid              # => client_id
    app.plaintext_secret # => client_secret — affiché UNE SEULE FOIS

Transmettre `uid` et `plaintext_secret` par un canal sûr. Le secret est hashé
en base : il n'est plus relisible ensuite (en cas de perte → rotation).

Un client délivré ainsi n'a aucun droit : seul `/api/ping` lui répond. Ne lui
accorder que les droits dont il a besoin.

### Droits d'un client

| Droit | Opération | Destinataires |
|-------|-----------|---------------|
| `internal:agents:create` | `POST /api/internal/agents` | systèmes internes, dont hub-api |

hub-api ne reçoit que `internal:agents:create`, et aucun autre droit.
L'enregistrement vérifie chaque code de flux auprès de hub-api. Le droit n'est
délivré aux systèmes internes, en recette comme en production, qu'une fois
`API_INTERNAL_ALLOWED_IPS` renseignée et les conditions d'exploitation de
l'espace interne vérifiées dans l'environnement concerné (« Endpoints internes »
ci-dessous).

    app = Doorkeeper::Application.find_by!(name: "nom-du-client")
    OauthApplicationRight.create!(oauth_application: app, right: "internal:agents:create")  # accorder
    OauthApplicationRight.find_by!(oauth_application: app, right: "internal:agents:create").destroy!  # retirer

Les droits sont lus à chaque appel : le changement vaut immédiatement, y compris
pour les jetons déjà délivrés. Un droit hors de `OauthApplicationRight::RIGHTS`
est refusé (faute de frappe).

Les droits ne sont pas des scopes OAuth : le client demande toujours son jeton
**sans `scope`**. Un `scope`, même le nom d'un droit, fait refuser le jeton
(400 `invalid_scope`).

### Révoquer un accès (effet immédiat)

    Doorkeeper::Application.find_by!(name: "nom-du-client").destroy!

Détruit le client, ses credentials, ses droits et tous ses tokens en cours.

### Renouveler un secret (rotation)

    app = Doorkeeper::Application.find_by!(name: "nom-du-client")
    app.renew_secret
    app.save!
    app.plaintext_secret # => nouveau secret — affiché UNE SEULE FOIS

Même `client_id`, nouveau secret. L'ancien secret est refusé immédiatement ;
les tokens déjà délivrés restent valides jusqu'à expiration (2 h max).

### Purge des tokens morts

Automatique : un job récurrent quotidien supprime les tokens expirés ou révoqués
(`purge_api_access_tokens`, `config/recurring.yml`). Aucun geste à faire.

### Vérifier des credentials (côté client)

    curl -s -X POST https://<hôte>/api/oauth/token -d "grant_type=client_credentials" -d "client_id=<uid>" -d "client_secret=<secret>"
    curl -s https://<hôte>/api/ping -H "Authorization: Bearer <access_token>"

## Endpoints internes (`/api/internal`)

Réservés aux systèmes internes de la plateforme. Une adresse hors liste reçoit la
même 404 JSON qu'une URL `/api/…` inexistante, avant toute vérification de jeton.

### Adresses autorisées : `API_INTERNAL_ALLOWED_IPS`

    API_INTERNAL_ALLOWED_IPS=192.0.2.5,198.51.100.0/24,2001:db8::/32

- IP ou plages CIDR (IPv4 ou IPv6), séparées par des virgules ; espaces tolérés.
- **Absente ou vide : tout est refusé** (hors développement, voir plus bas).
- Une entrée invalide (nom d'hôte, masque hors bornes, plage écrite avec une
  adresse qui n'en est pas le début, comme `192.0.2.5/24`, plage de toutes les
  adresses, `0.0.0.0/0` ou `::/0`) empêche le démarrage
  de l'application, avec un message qui nomme la variable et l'entrée.
- Lue au démarrage : un changement de liste demande un redémarrage.
- En développement, absente ou vide, elle vaut `127.0.0.1,::1` ; en test, valeur
  imposée.

### Conditions d'exploitation

L'adresse jugée est celle du pair TCP, sauf quand ce pair est un proxy de
confiance : c'est alors la **dernière** entrée de `X-Forwarded-For`. `Forwarded`
et `Client-IP` sont ignorés. Les proxies de confiance sont la liste par défaut de
Rails (`ActionDispatch::RemoteIp::TRUSTED_PROXIES` : boucle locale, plages
privées et lien local) ; elle ne suit pas un éventuel
`config.action_dispatch.trusted_proxies`. Cela suppose :

1. l'application n'est joignable que par le reverse proxy, jamais en direct :
   aucun de ses ports n'est publié hors de lui. Avec la redirection par défaut de
   Docker en IPv4, un port publié conserve l'adresse du client ; mais selon le
   mode (proxy userland : accès par la boucle locale, IPv6, Docker rootless,
   iptables désactivé), la requête arrive par une passerelle privée, donc de
   confiance, et un `X-Forwarded-For` forgé serait cru. Voir la vraie adresse du
   client lors d'un essai ne prouve donc pas que publier le port est sans risque ;
2. le reverse proxy **écrase** `X-Forwarded-For` au lieu de le compléter ;
3. le reverse proxy est le premier serveur atteint par la requête : un
   équipement en amont ferait juger son adresse à la place de celle du client ;
4. le reverse proxy joint l'application depuis la boucle locale ou une plage
   privée, en IPv4 (écoute par défaut de Puma) : une adresse publique, ou une
   IPv4 vue sous forme IPv6 (`::ffff:10.0.0.2`, si Puma écoute sur `[::]`), n'est
   pas reconnue comme proxy et c'est l'adresse du reverse proxy qui est jugée. Ne
   jamais inscrire l'adresse du reverse proxy dans `API_INTERNAL_ALLOWED_IPS` :
   tout client passant par lui serait admis ;
5. le reverse proxy **retire** `Forwarded` et `Client-IP`. Le filtre les ignore,
   mais Rails les croit pour `request.remote_ip`, qui est l'adresse écrite dans
   les journaux : sans ce retrait, un client y inscrit l'adresse de son choix.

Toute machine du réseau privé qui joint l'application en direct est un proxy de
confiance pour elle et peut donc annoncer l'adresse de son choix : d'où la
condition 1.

### Vérifier en recette

- depuis une IP non autorisée : 404 JSON sur `/api/internal/…` ;
- la même, avec `X-Forwarded-For: <IP d'un système interne autorisé>` : 404 ;
- depuis chaque système interne autorisé : la requête passe ;
- l'API publique (`/api/oauth/token`, `/api/ping`) répond comme avant.
