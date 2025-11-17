class DataPackage < ApplicationRecord
  include AASM

  # Delivery criteria: V1 supports only SIRET list
  # Future V2 will add: organization_id, subscription_id, _or/_and operators
  DELIVERY_CRITERIA_SUPPORTED = %w[siret].freeze
  DELIVERY_CRITERIA_MAX_SIRETS = 100

  belongs_to :data_stream
  belongs_to :sender_organization, class_name: "Organization"

  has_many :notifications, dependent: :destroy
  has_many :subscriptions, through: :notifications

  accepts_nested_attributes_for :notifications

  aasm column: :state do
    state :draft, initial: true
    state :transmitted
    state :acknowledged

    event :send_package do
      transitions from: :draft, to: :transmitted
    end

    event :acknowledge do
      transitions from: :transmitted, to: :acknowledged
      after { update_column(:acknowledged_at, Time.current) }
      error { errors.add(:state, "must be transmitted") }
    end
  end

  scope :by_state, ->(states) {
    return all unless states.is_a?(String)

    requested = states.split(",").map(&:strip)
    valid = DataPackage.aasm.states.map(&:name).map(&:to_s)
    valid_states = requested & valid  # Array intersection keeps only valid states
    valid_states.any? ? where(state: valid_states) : none
  }
  scope :by_data_stream, ->(id) { id.present? ? where(data_stream_id: id) : all }
  scope :by_sender_organization, ->(id) { id.present? ? where(sender_organization_id: id) : all }

  validates :state, presence: true
  validates :title, length: {maximum: 255}
  validates :delivery_criteria, delivery_criteria: true

  before_validation :generate_title, on: :create, if: -> { title.blank? }
  before_destroy :check_destroyable, prepend: true

  def can_be_destroyed?
    draft? || acknowledged?
  end

  def subscriptions_source
    draft? ? "resolver" : "notifications"
  end

  def has_completed_attachments?
    false  # Stub - will be implemented with Attachments feature
  end

  private

  def check_destroyable
    return true if can_be_destroyed?

    errors.add(:base, "Cannot destroy data_package in state: #{state}")
    throw :abort
  end

  def generate_title
    timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
    unique_id = SecureRandom.alphanumeric(4).upcase
    stream_name = data_stream&.name || "Package"
    self.title = "#{stream_name}-#{timestamp}-#{unique_id}"
  end
end
