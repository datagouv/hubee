# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        module Shared
          class CheckDataStreams
            include Interactor

            def call
              return unless form.valid_on?(:data_stream_codes)

              ask_referential(form.data_stream_codes_to_verify)
            end

            private

            def form = context.form

            # Chaque code inconnu a son motif ; une panne arrête la vérification, les codes
            # suivants restent à examiner au prochain appel.
            def ask_referential(codes)
              codes.each do |code|
                HubAPI::DataStreams.verify(code:)
              rescue HubAPI::NotFound
                (context.refusals ||= []) << [:unknown_data_stream, {code:}]
              end
            rescue HubAPI::Unavailable => e
              Rails.logger.error("Référentiel des flux indisponible — #{e.message}")
              context.unavailable = true
            end
          end
        end
      end
    end
  end
end
