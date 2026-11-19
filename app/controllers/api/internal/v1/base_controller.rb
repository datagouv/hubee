# frozen_string_literal: true

module API
  module Internal
    module V1
      class BaseController < API::BaseController
        include Pundit::Authorization

        rescue_from Pundit::NotAuthorizedError, with: :forbidden

        # Fermé par défaut, comme le portail : une action ajoutée qui oublierait d'autoriser explose au
        # lieu de servir tout client authentifié. Un rendu qui arrête la chaîne avant l'action (401 de
        # Doorkeeper) ou une exception rattrapée (403, 404, 400) n'atteint pas ce contrôle.
        after_action :verify_authorized

        private

        # Le sujet des policies est le client de l'API, qui porte ses droits.
        def pundit_user = current_api_client

        def forbidden = render(json: {error: "forbidden", message: I18n.t("api.errors.forbidden")}, status: :forbidden)

        # Le corps JSON brut, quand c'est un objet : les paramètres de Rails en altèrent des valeurs que
        # les forms veulent voir telles quelles. Tout autre corps vaut un corps vide.
        def raw_body
          @raw_body ||= begin
            body = JSON.parse(request.raw_post) if request.media_type == Mime[:json]
            body.is_a?(Hash) ? body : {}
          rescue JSON::ParserError
            {}
          end
        end

        # Un refus est un motif, ou un motif et les paramètres de son message. Un conflit
        # l'emporte ; l'indisponibilité seule n'est rendue que sans aucun motif.
        # Le contrôleur dit où chaque motif se range et son statut dans sa constante REFUSALS.
        def render_refusal(form, refusals)
          refusals_table = self.class::REFUSALS
          refusals.each { |reason, options = {}| form.errors.add(refusals_table.fetch(reason)[:attribute], reason, **options) }

          if form.errors.empty?
            render json: {error: "service_unavailable", message: I18n.t("api.internal.v1.unavailable")}, status: :service_unavailable
          elsif refusals.any? { |reason, _| refusals_table.fetch(reason)[:status] == :conflict }
            render json: form.error_details, status: :conflict
          else
            render json: form.error_details, status: :unprocessable_content
          end
        end
      end
    end
  end
end
