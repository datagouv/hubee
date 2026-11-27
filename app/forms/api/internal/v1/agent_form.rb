# frozen_string_literal: true

module API
  module Internal
    module V1
      # La demande d'enregistrement d'un agent : identité et un seul rattachement.
      class AgentForm
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Attributes::Normalization
        include DataStreamCodesList

        MEMBERSHIP_ATTRIBUTES = %i[siret insee_code role job_title phone_number mobile_phone_number data_stream_codes].freeze

        attribute :email, :string
        attribute :first_name, :string
        attribute :last_name, :string
        attribute :civility, :string
        attribute :siret, :string
        attribute :insee_code, :string
        attribute :role, :string
        attribute :job_title, :string
        attribute :phone_number, :string
        attribute :mobile_phone_number, :string
        # Sans type : toute valeur reçue est gardée telle quelle pour être refusée, jamais convertie.
        attribute :send_invitation, default: false
        attribute :source_info

        # Les normalisations des modèles : la valeur vérifiée est celle qui sera écrite et cherchée.
        normalizes :email, with: ->(email) { Agent.normalize_value_for(:email, email) }
        # Une chaîne vide vaut absence : un appelant peut relayer ainsi un champ non renseigné.
        normalizes :civility, with: ->(civility) { civility.presence }
        # Idem pour la fonction : sans cela, un champ laissé vide serait écrit comme une fonction vide.
        normalizes :job_title, with: ->(title) { title.presence }
        normalizes :phone_number, :mobile_phone_number, with: ->(number) { Membership.normalize_value_for(:phone_number, number) }

        # 254 : la borne d'une adresse (RFC 5321) ; le format seul n'en pose aucune.
        validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}, length: {maximum: 254}
        validates :first_name, :last_name, :siret, :insee_code, presence: true
        validates :civility, inclusion: {in: Agent.civilities.keys}, allow_nil: true
        validates :siret, format: {with: OrganizationLink::SIRET_FORMAT, allow_blank: true}
        # La base donne « member » par défaut : seul ce contrôle empêche un rôle oublié d'en devenir un.
        validates :role, presence: true, inclusion: {in: Membership.roles.keys, allow_blank: true}
        validates :job_title, length: {maximum: 255}
        validates :phone_number, :mobile_phone_number, format: {with: PhoneNumber::E164_FORMAT}, allow_nil: true
        validate :send_invitation_boolean
        validate :source_info_well_formed
        validate :data_stream_codes_required
        validate :member_habilitated

        def initialize(membership: {}, **identity)
          super(**identity, **membership)
        end

        # Ce setter note que la clé a été transmise, comme celui des codes de flux. `new` ne l'appelle que
        # pour une clé reçue (le contrôleur ne la passe que si le JSON la contient), jamais pour la valeur
        # par défaut. Une clé absente et une clé à `null` valent toutes deux nil : seul ce drapeau les sépare.
        # Absente, la source n'est pas tracée ; à `null`, elle est refusée.
        def source_info=(info)
          @source_info_given = true
          super
        end

        # Une vérification ne porte que sur des champs valides : les autres ont déjà leur motif.
        def valid_on?(*attributes) = attributes.none? { errors.include?(it) }

        # Une demande d'enregistrement vérifie tous les codes reçus auprès du référentiel.
        def data_stream_codes_to_verify = data_stream_codes

        # Les motifs reprennent l'imbrication du payload, enveloppe `agent` en moins.
        def error_details
          details = errors.to_hash
          membership = details.extract!(*MEMBERSHIP_ATTRIBUTES)
          membership.empty? ? details : details.merge(membership:)
        end

        private

        # Pas d'`inclusion` : Rails y admet une liste dont chaque élément est dans l'ensemble, [true] compris.
        def send_invitation_boolean
          errors.add(:send_invitation, :inclusion, value: send_invitation) unless [true, false].include?(send_invitation)
        end

        def source_info_well_formed
          errors.add(:source_info, :invalid) if @source_info_given && !well_formed_source_info?
        end

        def well_formed_source_info?
          source_info.is_a?(Hash) && source_info.all? { |key, value| admitted_source_info?(key, value) }
        end

        def admitted_source_info?(key, value)
          case key
          when "import" then [true, false].include?(value)
          when "job_id", "report_id" then value.nil? || value.is_a?(Integer)
          else false
          end
        end

        # Absente, la liste est refusée (`missing`) : la croire vide donnerait tous les flux à un
        # administrateur local. À `null`, ce n'est pas une liste (`not_a_list`).
        def data_stream_codes_required
          errors.add(:data_stream_codes, :missing) unless data_stream_codes_given?
        end

        # Un administrateur local sans habilitation a accès à tous les flux, un membre à aucun.
        def member_habilitated
          return unless role == "member" && valid_on?(:data_stream_codes)

          errors.add(:data_stream_codes, :required_for_member) if data_stream_codes.empty?
        end
      end
    end
  end
end
