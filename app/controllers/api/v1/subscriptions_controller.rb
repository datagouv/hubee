# frozen_string_literal: true

class Api::V1::SubscriptionsController < Api::BaseController
  before_action :set_subscription, only: [:show, :update, :destroy]

  def index
    @pagy, @subscriptions = pagy(
      Subscription
        .by_data_stream(params[:data_stream_id])
        .by_organization(params[:organization_id])
        .by_can_read(params[:can_read])
        .by_can_write(params[:can_write])
        .includes(:data_stream, :organization)
    )
  end

  def show
  end

  def create
    @subscription = Subscription.new(subscription_params)

    if @subscription.save
      render :show, status: :created
    else
      render json: @subscription.errors.messages, status: :unprocessable_content
    end
  end

  def update
    if @subscription.update(subscription_params)
      render :show, status: :ok
    else
      render json: @subscription.errors.messages, status: :unprocessable_content
    end
  end

  def destroy
    @subscription.destroy!
    head :no_content
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    permitted = params.expect(subscription: [:data_stream_id, :organization_id, :can_read, :can_write])
    permitted.reverse_merge!(data_stream_id: params[:data_stream_id]) if params[:data_stream_id].present?
    permitted
  end
end
