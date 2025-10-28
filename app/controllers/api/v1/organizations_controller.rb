module Api
  module V1
    class OrganizationsController < Api::BaseController
      before_action :set_organization, only: :show

      def index
        @pagy, @organizations = pagy(Organization.all)
      end

      def show
      end

      private

      def set_organization
        @organization = Organization.find_by!(siret: params[:siret])
      end
    end
  end
end
