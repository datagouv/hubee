# frozen_string_literal: true

module Portail
  # Ce qu'un rattachement a le droit de lire : tout, rien, ou une liste de flux.
  class ReadingPerimeter
    # Levée par `filter` sur un périmètre sans accès : transmis à l'amont, un filtre vide vaut
    # « aucun filtre », soit toute l'organisation.
    class NoAccess < StandardError; end

    class << self
      # Des habilitations renseignées bornent tout le monde, administrateur local compris. Le
      # rôle ne tranche que la liste vide.
      def for(membership)
        codes = membership.process_accesses.map(&:process_code)

        if codes.any?
          limited_to(codes)
        elsif membership.local_administrator?
          unrestricted
        else
          none
        end
      end

      def unrestricted = new(:unrestricted)

      def none = new(:none)

      def limited_to(codes) = new(:limited, codes)
    end

    def initialize(kind, codes = [])
      @kind = kind
      @codes = codes
    end

    def unrestricted? = @kind == :unrestricted

    def none? = @kind == :none

    def covers?(code) = unrestricted? || @codes.include?(code)

    # Ce que l'amont attend : une liste de flux, vide quand rien ne restreint la lecture.
    def filter
      raise NoAccess if none?

      @codes
    end
  end
end
