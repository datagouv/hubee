# frozen_string_literal: true

module Portail
  class Subscription
    # Les abonnements d'une organisation, tels que la frontière les rend : la liste complète, et
    # ce que le portail en projette.
    class List < Data.define(:subscriptions)
      # Les flux que l'organisation reçoit par le portail, chacun une fois : ce que le filtre
      # propose quand aucune habilitation ne restreint le rattachement.
      def portal_data_stream_codes
        subscriptions.select(&:readable_via_portal?).map(&:data_stream_code).uniq
      end

      # L'intitulé de chaque flux nommé, par code, quel que soit le canal : un intitulé ne
      # confère aucun droit. Sans intitulé, pas d'entrée : le repli sur le code appartient à
      # l'écran.
      def data_stream_names
        subscriptions.select { |subscription| subscription.data_stream_name.present? }
          .to_h { |subscription| [subscription.data_stream_code, subscription.data_stream_name] }
      end
    end
  end
end
