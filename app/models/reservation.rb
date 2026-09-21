class Reservation < ApplicationRecord
  DEFAULT_DURATION_MINUTES = 120
  LOCK_DURATION = 5.minutes

  belongs_to :user
  belongs_to :dining_table
  has_one :location, through: :dining_table

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" },
       default: :pending, validate: true

  before_validation :set_ends_at

  validates :starts_at, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :party_size, presence: true,
                         numericality: { only_integer: true, greater_than: 0 }
  validate :starts_at_in_future, on: :create
  validate :party_size_fits_table

  private

  def set_ends_at
    return unless starts_at && duration_minutes
    self.ends_at = starts_at + duration_minutes.minutes
  end

  def starts_at_in_future
    return unless starts_at
    errors.add(:starts_at, "muss in der Zukunft liegen") if starts_at <= Time.current
  end

  def party_size_fits_table
    return unless dining_table && party_size
    if party_size > dining_table.capacity
      errors.add(:party_size, "übersteigt die Kapazität des Tisches (#{dining_table.capacity} Plätze)")
    end
  end
end