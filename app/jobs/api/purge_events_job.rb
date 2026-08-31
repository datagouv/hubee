# frozen_string_literal: true

module API
  # La purge des traces est une obligation réglementaire : elle doit s'appliquer toute seule,
  # sans dépendre de quiconque y pense.
  class PurgeEventsJob < ApplicationJob
    def perform
      Event.expired.delete_all
    end
  end
end
