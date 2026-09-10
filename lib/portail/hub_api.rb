# frozen_string_literal: true

module Portail
  # La couche de traduction avec la gem cliente : le portail ne connaît que ses propres modèles
  # et ces erreurs-ci.
  module HubAPI
    class Error < StandardError; end

    # L'amont n'a pas répondu, ou pas de façon exploitable.
    class Unavailable < Error; end

    # Inexistante ou hors du périmètre interrogé, à dessein confondus : distinguer confirmerait
    # l'existence d'un dossier que l'agent n'a pas à voir.
    class NotFound < Error; end

    # La pièce est absente de la démarche, ou dans un état qui ne la rend pas livrable. Distincte
    # de NotFound, qui sur le chemin binaire signifie que le BORNAGE a refusé : là où celle-ci dit
    # une page périmée à l'intérieur d'une démarche légitimement consultée, l'autre dit une lecture
    # hors périmètre — et seule la seconde mérite le canal du CSIRT.
    class AttachmentNotFound < Error; end

    # L'amont n'a pas pu servir le contenu, et ne dit pas pourquoi : sur le chemin binaire, une
    # pièce dont le binaire a disparu et une vraie panne sortent du même code, indistinguables.
    # La gem refuse de trancher ce qu'elle ne sait pas, et nomme l'ambiguïté plutôt que de la
    # replier sur l'une des deux — replier sur « introuvable » rendrait toute panne silencieuse.
    #
    # ⚠️ Faux ami : ce n'est PAS Unavailable. Celle-ci dit « réessayez », promesse fausse pour un
    # fichier purgé, et part au rapporteur d'erreurs. Celle-là ne promet rien et n'y part pas :
    # une pièce disparue est un cas courant, pas un incident. C'est le VOLUME de ces refus qui
    # signale une panne, d'où le journal en avertissement plutôt que le silence.
    class AttachmentUnavailable < Error; end

    # L'historique de la démarche a atteint le nombre d'événements que l'amont accepte. Le
    # téléchargement doit y être inscrit avant d'être servi : sans place pour la trace, il ne peut
    # pas avoir lieu. Distincte d'Unavailable, qui promettrait un « réessayez » mensonger — rien
    # ne se libérera.
    class HistoryFull < Error; end

    # Paramètre refusé avant tout aller-retour réseau, typiquement un état ou une page trafiqués.
    # Montré à l'agent plutôt que corrigé en silence.
    class InvalidRequest < Error; end
  end
end
