# language: fr
Fonctionnalité: Connexion via ProConnect
  Le départ vers ProConnect et le retour traversent un vrai navigateur : Turbo, CSP et
  markup font partie du parcours et peuvent le casser sans qu'aucune spec ne le voie.
  ProConnect est simulé en local — le protocole, lui, est éprouvé par les specs.

  @javascript
  Scénario: Un agent rattaché se connecte
    Étant donné un agent rattaché à une organisation
    Et que ProConnect est prêt à l'authentifier
    Quand il se rend sur l'accueil
    Et qu'il clique sur "S'identifier avec ProConnect"
    Alors il est connecté au portail

  @javascript
  Scénario: L'agent se déconnecte ensuite
    Étant donné un agent rattaché à une organisation
    Et que ProConnect est prêt à l'authentifier
    Et qu'il s'est connecté
    Quand il clique sur "Se déconnecter"
    Alors il est revenu déconnecté à l'accueil
