# frozen_string_literal: true

module API
  module Internal
    module V1
      # La modification d'un rattachement : rôle, habilitations, fonction et téléphones. L'organisation
      # n'en fait pas partie : en changer, c'est retirer le rattachement puis en ajouter un.
      class MembershipUpdateForm
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Attributes::Normalization
        # Avant member_habilitated, qui lit valid_on?(:data_stream_codes) : la forme de la liste est jugée d'abord.
        include DataStreamCodesList

        SCALAR_ATTRIBUTES = %i[role job_title phone_number mobile_phone_number].freeze
        UPDATABLE_ATTRIBUTES = [*SCALAR_ATTRIBUTES, :data_stream_codes].freeze
        # L'organisation se lit pour être refusée : ignorée, une demande d'en changer passerait pour faite.
        IMMUTABLE_ATTRIBUTES = %i[siret insee_code].freeze
        # Les clés que le contrôleur transmet : les champs, le drapeau qui confirme une demande sans être un
        # champ du rattachement, et l'organisation, refusée.
        ACCEPTED_KEYS = [*UPDATABLE_ATTRIBUTES, :all_data_streams, *IMMUTABLE_ATTRIBUTES].freeze

        attr_reader :membership

        # Typés en chaîne : une valeur qui n'en est pas une devient sa représentation, que l'inclusion et
        # le format refusent. Rails admettrait sinon dans `inclusion` une liste de rôles valides.
        attribute :role, :string
        attribute :phone_number, :string
        attribute :mobile_phone_number, :string
        # Sans type : une liste deviendrait une fonction valide par sa représentation. Toute valeur
        # reçue est gardée telle quelle pour être refusée, jamais convertie.
        attribute :job_title
        # Sans type, pour la même raison : seul le booléen JSON est admis, jamais converti. Faux par défaut.
        attribute :all_data_streams, default: false
        # Gardées pour le message de leur refus, jamais écrites.
        attribute :siret
        attribute :insee_code

        # La normalisation de l'enregistrement : la valeur vérifiée est celle qui sera écrite. Une chaîne
        # vide vaut nil, et efface le numéro.
        normalizes :phone_number, :mobile_phone_number, with: ->(number) { Membership.normalize_value_for(:phone_number, number) }
        # Une chaîne vide vaut absence, comme pour la civilité : un formulaire HTML envoie « » pour un champ
        # laissé vide. Toute valeur qui n'est pas une chaîne reste telle quelle, pour être refusée.
        normalizes :job_title, with: ->(title) { title.is_a?(String) ? title.presence : title }

        # Une clé absente ne change rien, alors qu'une clé à `null` efface : seule la liste des clés reçues
        # les sépare, car les deux valent nil. Le rôle, lui, ne peut pas être vidé.
        validates :role, presence: true, inclusion: {in: Membership.roles.keys, allow_blank: true}, if: -> { given?(:role) }
        validates :job_title, length: {maximum: 255}, if: -> { job_title.is_a?(String) }
        validate :job_title_text
        validates :phone_number, :mobile_phone_number, format: {with: PhoneNumber::E164_FORMAT}, allow_nil: true
        validate :organization_unchanged
        validate :all_data_streams_boolean
        # Avant member_habilitated, qui ajoute son motif sur data_stream_codes : la confirmation ne lit que
        # la forme de la liste.
        validate :all_data_streams_confirmed
        validate :member_habilitated

        def initialize(membership:, **attributes)
          @membership = membership
          @given = attributes.keys.map(&:to_sym) & SCALAR_ATTRIBUTES
          @immutable_given = attributes.keys.map(&:to_sym) & IMMUTABLE_ATTRIBUTES
          super(**attributes.slice(*ACCEPTED_KEYS))
        end

        # Les codes déjà accordés ne sont pas revérifiés : un code disparu du référentiel ne doit pas
        # bloquer la correction d'un autre champ.
        def data_stream_codes_to_verify
          data_stream_codes_given? ? data_stream_codes - membership.data_stream_codes : []
        end

        # Les champs reçus dont la valeur normalisée diffère de celle du rattachement : `{champ: [avant,
        # après]}`. Les codes se comparent comme des ensembles et se rendent triés : leur ordre ne dit rien.
        def changes
          changes = @given.to_h { [it, [membership.public_send(it), public_send(it)]] }
          changes[:data_stream_codes] = [membership.data_stream_codes.sort, data_stream_codes.sort] if data_stream_codes_given?
          changes.reject { |_, (before, after)| before == after }
        end

        # Une vérification ne porte que sur des champs valides : les autres ont déjà leur motif.
        def valid_on?(*attributes) = attributes.none? { errors.include?(it) }

        def error_details = errors.to_hash

        private

        def given?(attribute) = @given.include?(attribute)

        def job_title_text
          errors.add(:job_title, :invalid) unless job_title.nil? || job_title.is_a?(String)
        end

        # Présente, la clé est refusée quelle que soit sa valeur, même celle du rattachement.
        def organization_unchanged
          @immutable_given.each { errors.add(it, :immutable) }
        end

        # Pas d'`inclusion` : Rails y admet une liste dont chaque élément est dans l'ensemble, [true] compris.
        def all_data_streams_boolean
          errors.add(:all_data_streams, :inclusion, value: all_data_streams) unless [true, false].include?(all_data_streams)
        end

        # Une liste vide ouvre à un administrateur local tous les flux de son organisation : décocher son
        # dernier flux lui donnerait plus. Y parvenir exige donc `all_data_streams: true`, sauf s'il y est
        # déjà (un rejeu passe). Le drapeau n'a pas d'autre emploi. Comme member_habilitated, la règle
        # porte sur l'état résultant et l'état actuel, que Save relit sous le verrou.
        def all_data_streams_confirmed
          return unless valid_on?(:role, :data_stream_codes, :all_data_streams)

          if !grants_all_data_streams?(resulting_role, resulting_data_stream_codes)
            errors.add(:all_data_streams, :requires_empty_list) if all_data_streams
          elsif !all_data_streams && !grants_all_data_streams?(membership.role, membership.data_stream_codes)
            errors.add(:data_stream_codes, :grants_all_data_streams)
          end
        end

        def grants_all_data_streams?(role, codes) = role == "local_administrator" && codes.empty?

        # Un administrateur local sans habilitation a accès à tous les flux, un membre à aucun. La règle
        # porte sur l'état qui résultera de la demande : rôle et codes reçus, ou ceux du rattachement.
        # Ceux-ci peuvent changer d'ici l'écriture : Save rejuge le form sous le verrou.
        def member_habilitated
          return unless resulting_role == "member" && valid_on?(:data_stream_codes)

          errors.add(:data_stream_codes, :required_for_member) if resulting_data_stream_codes.empty?
        end

        def resulting_role = given?(:role) ? role : membership.role

        def resulting_data_stream_codes = data_stream_codes_given? ? data_stream_codes : membership.data_stream_codes
      end
    end
  end
end
