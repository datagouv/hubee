# frozen_string_literal: true

module Portail
  class Subscription
    # Les abonnements d'une organisation, tels que la frontière les rend : la liste complète, et
    # ce que le portail en projette.
    class List < Data.define(:subscriptions)
      include Enumerable

      def each(&) = subscriptions.each(&)

      # Les flux que l'organisation reçoit par le portail, chacun une fois, triés : ce que le
      # filtre propose quand aucune habilitation ne restreint le rattachement.
      def portal_data_stream_codes
        select(&:readable_via_portal?).map { |subscription| subscription.data_stream.code }.uniq.sort
      end
    end
  end
end
