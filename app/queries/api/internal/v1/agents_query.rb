# frozen_string_literal: true

module API
  module Internal
    module V1
      # La recherche d'agents de l'espace interne : chaque critère présent restreint la liste, les
      # rattachements de chaque agent restent rendus en entier.
      class AgentsQuery
        # Les formes sous lesquelles une saisie est comparée : l'adresse, le prénom, le nom, « prénom nom » et « nom prénom ».
        SEARCHED_EXPRESSIONS = [
          "agents.email",
          "agents.first_name",
          "agents.last_name",
          "agents.first_name || ' ' || agents.last_name",
          "agents.last_name || ' ' || agents.first_name"
        ].freeze

        def initialize(relation = Agent.all)
          @relation = relation
        end

        def call(siret: nil, insee_code: nil, role: nil, search: nil)
          @relation
            .then { filter_by_membership(it, siret:, insee_code:, role:) }
            .then { search_text(it, search) }
            .order(:email)
            .preload(memberships: %i[organization_link data_stream_accesses])
        end

        private

        # Les trois critères désignent un même rattachement : un agent membre sur un SIRET et
        # administrateur sur un autre ne répond pas à « administrateur de ce SIRET ».
        def filter_by_membership(relation, siret:, insee_code:, role:)
          criteria = {role:, organization_links: {siret:, insee_code:}.compact_blank}.compact_blank
          return relation if criteria.empty?

          relation.where(id: Membership.joins(:organization_link).where(criteria).select(:agent_id))
        end

        # Le début de l'un des champs, sans casse, le tiret valant l'espace des deux côtés. La saisie et les
        # champs passent par le même `lower`, celui de la base : la casse se replie d'une seule façon. Pas
        # d'index : 0,17 s au pire, mesuré le 18/11 sur un jeu de mesure. Un index d'expression devrait
        # reproduire ces expressions au caractère près, sans quoi PostgreSQL l'ignorerait sans erreur.
        def search_text(relation, text)
          return relation if text.blank?

          pattern = "#{Agent.sanitize_sql_like(text.tr("-", " "))}%"
          conditions = SEARCHED_EXPRESSIONS.map { "lower(translate(#{it}, '-', ' ')) LIKE lower(:pattern)" }
          relation.where(conditions.join(" OR "), pattern:)
        end
      end
    end
  end
end
