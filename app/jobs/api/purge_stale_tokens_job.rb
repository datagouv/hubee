# frozen_string_literal: true

module API
  # Doorkeeper ne supprime jamais les tokens morts : sans purge, expirés et révoqués
  # s'accumulent en base indéfiniment.
  class PurgeStaleTokensJob < ApplicationJob
    def perform
      cleaner = Doorkeeper::StaleRecordsCleaner.new(Doorkeeper::AccessToken)
      cleaner.clean_revoked
      cleaner.clean_expired(Doorkeeper.config.access_token_expires_in)
    end
  end
end
