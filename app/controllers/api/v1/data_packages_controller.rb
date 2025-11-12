class Api::V1::DataPackagesController < Api::BaseController
  before_action :set_data_package, only: %i[show destroy]

  def index
    @pagy, @data_packages = pagy(
      DataPackage
        .by_state(params[:state])
        .by_data_stream(params[:data_stream_id])
        .by_sender_organization(params[:sender_organization_id])
        .includes(:data_stream, :sender_organization)
    )
  end

  def show
  end

  def create
    # sender_organization_id devrait être déterminé par les credentials de l'utilisateur
    # sauf si c'est un admin, dans ce cas il a le droit d'envoyer cette donnée.
    @data_package = DataPackage.new(data_package_params)

    if @data_package.save
      render :show, status: :created
    else
      render json: @data_package.errors, status: :unprocessable_content
    end
  end

  def destroy
    if @data_package.destroy
      head :no_content
    else
      render json: @data_package.errors, status: :unprocessable_content
    end
  end

  private

  def set_data_package
    @data_package = DataPackage.find(params[:id])
  end

  def data_package_params
    permitted = params.expect(data_package: [:data_stream_id, :sender_organization_id, :title])
    permitted.reverse_merge!(data_stream_id: params[:data_stream_id]) if params[:data_stream_id].present?
    permitted
  end
end
