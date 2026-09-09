# frozen_string_literal: true

module Portail
  class Subscription
    # Les abonnements d'une organisation, tels que la frontière les rend : la liste complète, et
    # ce que le portail en projette.
    class List < Data.define(:subscriptions)
      # Les flux que l'organisation reçoit par le portail, chacun une fois : ce que le filtre
      # propose quand aucune habilitation ne restreint le rattachement.
      def portal_data_stream_codes
        subscriptions.select(&:readable_via_portal?).map { |subscription| subscription.data_stream.code }.uniq
      end
    end
  end
end
