# frozen_string_literal: true

module Portail
  class Delivery
    # Ce que l'agent demande à la liste, lu dans l'URL et réécrit dans chaque lien de la page : le
    # filtre et le tri survivent au changement d'état et de page. Les valeurs restent des chaînes :
    # aucune validation ici, l'amont tranche et son refus est affiché plutôt que corrigé en douce.
    class Criteria < Data.define(
      :state, :data_stream_code, :transmitted_from, :transmitted_to, :sort, :direction
    )
      # La liste s'ouvre sur les démarches que l'agent n'a pas encore prises en charge, son
      # travail du jour ; ouvrir sur « traitée » ou « clôturée » montrerait d'abord l'archive.
      DEFAULT_STATE = "transmitted"
      # Les plus récentes d'abord, le seul tri que l'amont sert sans surcoût.
      DEFAULT_SORT = "transmitted_at"
      DEFAULT_DIRECTION = "desc"

      # Clé : l'attribut de Criteria ; valeur : le nom du paramètre d'URL, en français comme les chemins.
      PARAM_NAMES = {
        state: :statut, data_stream_code: :flux, transmitted_from: :du, transmitted_to: :au,
        sort: :tri, direction: :ordre
      }.freeze

      DEFAULTS = {
        state: DEFAULT_STATE, sort: DEFAULT_SORT, direction: DEFAULT_DIRECTION
      }.freeze

      class << self
        # `.to_s` : `?statut[]=…` fait de la valeur un tableau, qui part tel quel se faire refuser.
        # `.presence` : un champ de formulaire laissé vide retombe sur le défaut.
        def from_params(params)
          new(**PARAM_NAMES.to_h { |member, name|
            [member, params[name].to_s.presence || DEFAULTS[member]]
          })
        end
      end

      # Ce que chaque lien de la page réécrit, menu d'états, pagination, en-têtes triables. Les
      # défauts n'y figurent pas : chaque lien porterait sinon un tri implicite. L'état, lui, y
      # est toujours : c'est la page.
      def link_params
        PARAM_NAMES.filter_map { |member, name|
          value = public_send(member)
          [name, value] if member == :state || (value && value != DEFAULTS[member])
        }.to_h
      end

      def filtered? = [data_stream_code, transmitted_from, transmitted_to].any?
    end
  end
end
