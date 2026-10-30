# frozen_string_literal: true

module API
  module Internal
    # La demande d'enregistrement d'un agent : identité et un seul rattachement.
    class AgentForm
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      # 51 codes en production au 26/10/2026 : la borne arrête un appel abusif, même interne.
      MAX_DATA_STREAM_CODES = 100

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
      attribute :data_stream_codes

      # Les normalisations des modèles : la valeur vérifiée est celle qui sera écrite et cherchée.
      normalizes :email, with: ->(email) { Agent.normalize_value_for(:email, email) }
      # Une chaîne vide vaut absence : un appelant peut relayer ainsi un champ non renseigné.
      normalizes :civility, with: ->(civility) { civility.presence }
      normalizes :phone_number, :mobile_phone_number, with: ->(number) { Membership.normalize_value_for(:phone_number, number) }
      # Seul un doublon exact est retiré : un code est opaque, sa casse n'est jamais changée.
      # Ce qui n'est pas une liste de chaînes est gardé tel quel, pour son motif.
      normalizes :data_stream_codes, with: ->(codes) {
        next codes unless codes.is_a?(Array) && codes.all?(String)

        codes.map { DataStreamAccess.normalize_value_for(:data_stream_code, it) }.uniq
      }

      validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP, allow_blank: true}
      validates :first_name, :last_name, :siret, :insee_code, presence: true
      validates :civility, inclusion: {in: Agent.civilities.keys}, allow_nil: true
      validates :siret, format: {with: OrganizationLink::SIRET_FORMAT, allow_blank: true}
      # La base donne « member » par défaut : seul ce contrôle empêche un rôle oublié d'en devenir un.
      validates :role, presence: true, inclusion: {in: Membership.roles.keys, allow_blank: true}
      validates :job_title, length: {maximum: 255}
      validates :phone_number, :mobile_phone_number, format: {with: PhoneNumber::E164_FORMAT}, allow_nil: true
      validate :data_stream_codes_well_formed
      validate :member_habilitated

      def initialize(membership: {}, **identity)
        super(**identity, **membership)
      end

      # Une liste absente n'est pas une liste vide : seule la seconde donne tous les flux à un
      # administrateur local.
      def data_stream_codes=(codes)
        @data_stream_codes_given = true
        super
      end

      # Une vérification ne porte que sur des champs valides : les autres ont déjà leur motif.
      def valid_on?(*attributes) = attributes.none? { errors.include?(it) }

      # Les motifs reprennent l'imbrication du payload, enveloppe `agent` en moins.
      def error_details
        details = errors.to_hash
        membership = details.extract!(*MEMBERSHIP_ATTRIBUTES)
        membership.empty? ? details : details.merge(membership:)
      end

      private

      # Au-delà de la borne, les codes ne sont pas examinés un à un : la réponse ne les renvoie pas.
      def data_stream_codes_well_formed
        if !@data_stream_codes_given
          errors.add(:data_stream_codes, :missing)
        elsif !(data_stream_codes.is_a?(Array) && data_stream_codes.all?(String))
          errors.add(:data_stream_codes, :not_a_list)
        elsif data_stream_codes.size > MAX_DATA_STREAM_CODES
          errors.add(:data_stream_codes, :too_many, count: MAX_DATA_STREAM_CODES)
        else
          invalid_data_stream_codes.each { errors.add(:data_stream_codes, :invalid_code, code: it) }
        end
      end

      def invalid_data_stream_codes = data_stream_codes.grep_v(DataStreamCode::FORMAT)

      # Un administrateur local sans habilitation a accès à tous les flux, un membre à aucun.
      def member_habilitated
        return unless role == "member" && valid_on?(:data_stream_codes)

        errors.add(:data_stream_codes, :required_for_member) if data_stream_codes.empty?
      end
    end
  end
end
