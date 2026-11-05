# frozen_string_literal: true

module API
  class PurgeEventsJob < ApplicationJob
    def perform
      Event.expired.delete_all
    end
  end
end
