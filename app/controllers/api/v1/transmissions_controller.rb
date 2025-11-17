class Api::V1::TransmissionsController < Api::BaseController
  before_action :set_data_package

  def create
    result = DataPackages::Transmit.call(data_package: @data_package)

    if result.success?
      render "api/v1/data_packages/show", status: :ok
    else
      render json: error_response(result.error), status: :unprocessable_content
    end
  end

  private

  def set_data_package
    @data_package = DataPackage.find(params[:data_package_id])
  end

  def error_response(error)
    case error
    when :not_draft
      {state: ["must be draft"]}
    when :no_completed_attachments
      {state: ["must have completed attachments"]}
    when :no_recipients
      {base: ["must have at least one recipient subscription"]}
    else
      {base: ["transmission failed"]}
    end
  end
end
