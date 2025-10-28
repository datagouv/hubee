module Api
  module V1
    class DataStreamsController < Api::BaseController
      before_action :set_data_stream, only: %i[show update destroy]

      def index
        @pagy, @data_streams = pagy(DataStream.includes(:owner_organization).all)
      end

      def show
      end

      def create
        @data_stream = DataStream.new(data_stream_params)

        if @data_stream.save
          render :show, status: :created
        else
          render json: @data_stream.errors, status: :unprocessable_entity
        end
      end

      def update
        if @data_stream.update(data_stream_params)
          render :show, status: :ok
        else
          render json: @data_stream.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @data_stream.destroy
        head :no_content
      end

      private

      def set_data_stream
        @data_stream = DataStream.find_by!(uuid: params[:uuid])
      end

      def data_stream_params
        params.expect(data_stream: [:name, :description, :retention_days, :owner_organization_siret]).tap do |whitelisted|
          if whitelisted[:owner_organization_siret].present?
            organization = Organization.find_by(siret: whitelisted[:owner_organization_siret])
            whitelisted[:owner_organization_id] = organization&.id
            whitelisted.delete(:owner_organization_siret)
          end
        end
      end
    end
  end
end
