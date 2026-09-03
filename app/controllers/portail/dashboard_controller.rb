# frozen_string_literal: true

module Portail
  class DashboardController < Portail::BaseController
    allow_unauthenticated_access

    def index
      redirect_to demarches_path if agent_signed_in?
    end
  end
end
