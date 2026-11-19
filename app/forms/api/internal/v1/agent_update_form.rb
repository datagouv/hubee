# frozen_string_literal: true

module API
  module Internal
    module V1
      # La correction de l'adresse et de la civilité d'un agent. Prénom et nom n'en font pas partie :
      # le fournisseur d'identité les réécrit à chaque connexion.
      class AgentUpdateForm
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Attributes::Normalization

        CORRECTABLE_ATTRIBUTES = %i[email civility].freeze

        attr_reader :agent

        attribute :email, :string
        attribute :civility, :string

        # Les normalisations de l'enregistrement : la valeur vérifiée est celle qui sera écrite et cherchée.
        normalizes :email, with: ->(email) { Agent.normalize_value_for(:email, email) }
        # Une chaîne vide vaut absence : elle efface la civilité.
        normalizes :civility, with: ->(civility) { civility.presence }

        # Une clé absente ne change rien, alors qu'une clé à `null` efface : seule la liste des clés reçues
        # les sépare, car les deux valent nil. Elle ne retient que les champs corrigeables.
        # 254 : la borne d'une adresse (RFC 5321) ; le format seul n'en pose aucune.
        validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}, length: {maximum: 254}, if: -> { given?(:email) }
        validates :civility, inclusion: {in: Agent.civilities.keys}, allow_nil: true

        def initialize(agent:, **attributes)
          @agent = agent
          @given = attributes.keys.map(&:to_sym) & CORRECTABLE_ATTRIBUTES
          super(**attributes.slice(*CORRECTABLE_ATTRIBUTES))
        end

        # Les champs reçus dont la valeur normalisée diffère de celle de l'agent : `{champ: [avant, après]}`.
        def changes
          @given.to_h { [it, [agent.public_send(it), public_send(it)]] }.reject { |_, (before, after)| before == after }
        end

        def email_changed? = changes.key?(:email)

        # Une vérification ne porte que sur des champs valides : les autres ont déjà leur motif.
        def valid_on?(*attributes) = attributes.none? { errors.include?(it) }

        def error_details = errors.to_hash

        private

        def given?(attribute) = @given.include?(attribute)
      end
    end
  end
end
