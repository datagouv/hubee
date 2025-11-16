# frozen_string_literal: true

class Api::V1::DataPackages::SubscriptionsController < Api::BaseController
  before_action :set_data_package

  def index
    @pagy, @subscriptions = pagy(resolve_subscriptions)
  rescue DeliveryCriteriaValidator::Invalid => e
    render json: {error: e.message}, status: :unprocessable_content
  end

  private

  def set_data_package
    @data_package = DataPackage.find(params[:data_package_id])
  end

  def resolve_subscriptions
    if @data_package.draft?
      # Preview mode: use resolver to find potential subscriptions
      DeliveryCriteria::Resolver.resolve(
        @data_package.delivery_criteria,
        @data_package.data_stream
      ).includes(:organization)
    else
      # Already transmitted: use actual notifications
      @data_package.subscriptions.includes(:organization)
    end
  end
end
