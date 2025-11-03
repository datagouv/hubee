class Api::V1::TransmissionsController < Api::BaseController
  before_action :set_data_package

  def create
    if @data_package.send_package!
      render "api/v1/data_packages/show", status: :ok
    else
      render json: @data_package.errors, status: :unprocessable_content
    end
  end

  private

  def set_data_package
    @data_package = DataPackage.find(params[:data_package_id])
  end
end
