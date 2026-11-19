# frozen_string_literal: true

module API
  module Internal
    module V1
      # La liste des codes de flux d'une demande, partagée par les forms qui en portent une : sa forme,
      # sa normalisation et sa validation. Le form hôte inclut ActiveModel::Attributes et sa normalisation.
      # À inclure avant toute validation qui lit valid_on?(:data_stream_codes) : l'ordre de déclaration fait foi.
      module DataStreamCodesList
        extend ActiveSupport::Concern

        # 51 codes en production au 26/10/2026 : la borne arrête un appel abusif, même interne.
        MAX_DATA_STREAM_CODES = 100

        included do
          attribute :data_stream_codes

          # Seul un doublon exact est retiré : un code est opaque, sa casse n'est jamais changée.
          # Ce qui n'est pas une liste de chaînes est gardé tel quel, pour son motif.
          normalizes :data_stream_codes, with: ->(codes) {
            next codes unless codes.is_a?(Array) && codes.all?(String)

            codes.map { DataStreamAccess.normalize_value_for(:data_stream_code, it) }.uniq
          }

          validate :data_stream_codes_well_formed, if: :data_stream_codes_given?

          # Défini ici, sur la classe, et non dans le module : l'attribut est déclaré par ce bloc, après
          # l'inclusion, et le module généré par `attribute` passerait devant un setter du concern.
          #
          # Ce setter note que la clé a été transmise. `new` ne l'appelle que pour une clé reçue (le
          # contrôleur ne la passe que si le JSON la contient), jamais pour la valeur par défaut.
          # Une clé absente et une clé à `null` valent toutes deux nil : seul ce drapeau les sépare.
          def data_stream_codes=(codes)
            @data_stream_codes_given = true
            super
          end
        end

        def data_stream_codes_given? = !!@data_stream_codes_given

        private

        # Au-delà de la borne, les codes ne sont pas examinés un à un : la réponse ne les renvoie pas.
        def data_stream_codes_well_formed
          if !(data_stream_codes.is_a?(Array) && data_stream_codes.all?(String))
            errors.add(:data_stream_codes, :not_a_list)
          elsif data_stream_codes.size > MAX_DATA_STREAM_CODES
            errors.add(:data_stream_codes, :too_many, count: MAX_DATA_STREAM_CODES)
          else
            invalid_data_stream_codes.each { errors.add(:data_stream_codes, :invalid_code, code: it) }
          end
        end

        def invalid_data_stream_codes = data_stream_codes.grep_v(DataStreamCode::FORMAT)
      end
    end
  end
end
