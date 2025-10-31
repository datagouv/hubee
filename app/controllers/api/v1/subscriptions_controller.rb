# frozen_string_literal: true

class Api::V1::SubscriptionsController < Api::BaseController
  before_action :set_subscription, only: [:show, :update, :destroy]

  def index
    @pagy, @subscriptions = pagy(subscriptions_scope.includes(:data_stream, :organization))
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
    @subscription = Subscription.find_by!(uuid: params[:uuid])
  end

  def subscriptions_scope
    scope = Subscription.all

    if params[:data_stream_uuid].present?
      data_stream = DataStream.find_by!(uuid: params[:data_stream_uuid])
      scope = scope.where(data_stream: data_stream)
    end

    if params[:organization_siret].present?
      organization = Organization.find_by!(siret: params[:organization_siret])
      scope = scope.where(organization: organization)
    end

    apply_permission_filters(scope)
  end

  def apply_permission_filters(scope)
    return scope unless params[:permission_type].present?

    permission_types = params[:permission_type].split(",").map(&:strip)
    scope.where(permission_type: permission_types)
  end

  def subscription_params
    params_hash = params.expect(subscription: [:data_stream_id, :organization_id, :permission_type])

    if params[:data_stream_uuid].present?
      data_stream = DataStream.find_by!(uuid: params[:data_stream_uuid])
      params_hash[:data_stream_id] = data_stream.id
    elsif params_hash[:data_stream_id].present?
      data_stream = DataStream.find_by!(uuid: params_hash[:data_stream_id])
      params_hash[:data_stream_id] = data_stream.id
    end

    if params_hash[:organization_id].present?
      organization = Organization.find_by!(siret: params_hash[:organization_id])
      params_hash[:organization_id] = organization.id
    end

    params_hash
  end
end
