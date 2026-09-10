# frozen_string_literal: true

module Portail
  class Delivery
    # Ce que l'agent demande à la liste, lu dans l'URL et réécrit dans chaque lien de la page : le
    # filtre et le tri survivent au changement d'état et de page. Les valeurs restent des chaînes :
    # aucune validation ici, l'amont tranche et son refus est affiché plutôt que corrigé en douce.
    class Criteria < Data.define(
      :state, :data_stream_codes, :number, :transmitted_from, :transmitted_to, :sort, :direction
    )
      # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
      # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
      DEFAULT_STATE = "transmitted"
      # Les plus récentes d'abord, le seul tri que l'amont sert sans surcoût.
      DEFAULT_SORT = "transmitted_at"
      DEFAULT_DIRECTION = "desc"

      # Clé : l'attribut de Criteria ; valeur : le nom du paramètre d'URL, en français comme les chemins.
      PARAM_NAMES = {
        state: :statut, data_stream_codes: :flux, number: :numero, transmitted_from: :du,
        transmitted_to: :au, sort: :tri, direction: :ordre
      }.freeze

      DEFAULTS = {
        state: DEFAULT_STATE, data_stream_codes: [], sort: DEFAULT_SORT, direction: DEFAULT_DIRECTION
      }.freeze

      # Tout critère restreint la liste, sauf l'état, qui est la page, et le tri.
      FILTERS = (members - %i[state sort direction]).freeze

      class << self
        def from_params(params)
          new(**PARAM_NAMES.to_h { |member, name| [member, read(member, params[name])] })
        end

        private

        # `.to_s` : `?statut[]=…` fait de la valeur un tableau, qui part tel quel se faire refuser.
        # `.presence` : un champ laissé vide retombe sur le défaut. `.strip` : l'amont ne retire pas
        # les blancs d'un numéro collé.
        def read(member, value)
          case member
          when :data_stream_codes then Array(value).filter_map { |code| code.to_s.presence }.uniq
          when :number then value.to_s.strip.presence
          else value.to_s.presence || DEFAULTS[member]
          end
        end
      end

      # Réécrit dans chaque lien de la page. Les défauts n'y figurent pas, sauf l'état : c'est
      # la page.
      def link_params
        PARAM_NAMES.filter_map { |member, name|
          value = public_send(member)
          [name, value] if member == :state || (value.present? && value != DEFAULTS[member])
        }.to_h
      end

      def filtered? = FILTERS.any? { |member| public_send(member).present? }
    end
  end
end
