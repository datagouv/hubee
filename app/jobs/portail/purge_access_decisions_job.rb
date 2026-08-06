# frozen_string_literal: true

module Portail
  # La purge des traces est une obligation réglementaire : elle doit s'appliquer toute
  # seule, sans dépendre de quiconque y pense.
  class PurgeAccessDecisionsJob < ApplicationJob
    def perform
      AccessDecision.expired.delete_all
    end
  end
end
