# frozen_string_literal: true

module API
  module Agents
    class Create
      include Interactor::Organizer

      # Tout ou rien : un appel invalide n'écrit rien, ni agent sans trace ni trace sans agent.
      around do |organizer|
        ActiveRecord::Base.transaction { organizer.call }
      end

      organize ValidatePayload, FindOrCreateOrganizationLinks, CreateAgent,
        CreateMemberships, RecordTraces
    end
  end
end
