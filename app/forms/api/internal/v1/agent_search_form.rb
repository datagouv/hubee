# frozen_string_literal: true

module API
  module Internal
    module V1
      # Les critères de recherche d'agents, tous facultatifs : un critère absent ne filtre pas. La
      # pagination aussi : absente, la première page de 50.
      class AgentSearchForm
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Attributes::Normalization

        # Bornes de la pagination. Au-delà de la millième page, le stock serait épuisé depuis longtemps ;
        # sans borne, une page démesurée déborde l'entier de la base (500).
        MAX_PAGE = 1000
        MAX_PER_PAGE = 100
        DEFAULT_PER_PAGE = 50
        CRITERIA = %i[siret insee_code role search].freeze

        # Sans type : la valeur reçue est jugée telle quelle. Une liste deviendrait sinon sa
        # représentation, et un décimal un entier.
        CRITERIA.each { attribute it }
        attribute :page
        attribute :per_page

        # Une valeur vide vaut critère absent : un appelant peut relayer ainsi un champ non renseigné.
        # Ce qui n'est pas une chaîne reste tel quel, pour son motif.
        normalizes(*CRITERIA, :page, :per_page, with: ->(value) { value.is_a?(String) ? value.strip.presence : value })

        validate :criteria_strings
        validates :siret, format: {with: OrganizationLink::SIRET_FORMAT}, if: -> { siret.is_a?(String) }
        # Rails admet dans `inclusion` une liste dont chaque élément est dans l'ensemble : une chaîne seulement.
        validates :role, inclusion: {in: Membership.roles.keys}, if: -> { role.is_a?(String) }
        validates :search, length: {maximum: 255}, if: -> { search.is_a?(String) }
        validate :insee_code_with_siret
        validates :page, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_PAGE}, allow_nil: true
        validates :per_page, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_PER_PAGE}, allow_nil: true

        def criteria = {siret:, insee_code:, role:, search:}

        # À lire sur un form valide : la page et sa taille, en entiers.
        def pagination = {page: page&.to_s&.to_i || 1, limit: per_page&.to_s&.to_i || DEFAULT_PER_PAGE}

        def error_details = errors.to_hash

        private

        # Un critère non scalaire écarté en silence ne filtrerait plus : la réponse serait tout le stock.
        def criteria_strings
          CRITERIA.reject { string_or_nil?(public_send(it)) }.each { errors.add(it, :not_a_string) }
        end

        def string_or_nil?(value) = value.nil? || value.is_a?(String)

        # Un code guichet n'a de sens que dans une organisation : seul, il désignerait des rattachements sans lien entre eux.
        def insee_code_with_siret
          errors.add(:insee_code, :requires_siret) if insee_code && !siret
        end
      end
    end
  end
end
