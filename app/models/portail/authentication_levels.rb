# frozen_string_literal: true

module Portail
  # Le vocabulaire `acr` de ProConnect et ce que le portail en fait : ce qu'on exige au
  # départ, ce qu'on accepte au retour, ce qui vaut second facteur.
  #
  # Les trois vivaient séparément — dans le client OIDC, dans un interactor, dans
  # SecondFactor — liées par une relation qu'aucun code n'exprimait : ajouter un niveau
  # demandait trois modifications, et rien ne signalait l'oubli.
  module AuthenticationLevels
    # ProConnect gradue l'authentification sur trois dimensions : la preuve d'identité, la
    # méthode d'authentification, et le lien organisationnel. Au niveau 0 ce dernier est
    # déclaratif — l'agent affirme son organisation sans que personne ne l'atteste —, y
    # compris avec un second facteur. D'où un plancher à eidas1, et un refus qui porte sur
    # le niveau et non sur l'absence de MFA : `eidas0-mfa` est aussi déclaratif qu'`eidas0`.
    MINIMUM = "eidas1"

    # Ceux qui attestent un second facteur. `eidas1` seul est mono-facteur.
    SECOND_FACTOR = %w[eidas1-mfa eidas2 eidas3].freeze

    # Dérivé, jamais recopié : c'est ce qui rend impossible la désynchronisation d'avant.
    ACCEPTED = [MINIMUM, *SECOND_FACTOR].freeze

    module_function

    # Ce qu'on demande à ProConnect. Une élévation n'accepte plus le plancher, sinon la
    # requête porterait deux consignes contradictoires.
    def demanded(step_up:) = step_up ? SECOND_FACTOR : [MINIMUM]

    def accepted?(acr) = ACCEPTED.include?(acr)

    def second_factor?(acr) = SECOND_FACTOR.include?(acr)
  end
end
