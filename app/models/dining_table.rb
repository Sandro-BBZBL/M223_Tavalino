class DiningTable < ApplicationRecord
  belongs_to :location
  has_many :reservations, dependent: :restrict_with_error

  validates :number, presence: true,
                     numericality: { only_integer: true, greater_than: 0 },
                     uniqueness: { scope: :location_id }
  validates :capacity, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :seating_at_least, ->(party_size) { where("capacity >= ?", party_size) }

  # Freie Tische eines Standorts für einen Zeitraum und eine Personenzahl.
  # Kleinster passender Tisch zuerst, damit grosse Tische nicht verschwendet werden.
  def self.available_for(location:, starts_at:, party_size:,
                         duration_minutes: Reservation::DEFAULT_DURATION_MINUTES)
    ends_at = starts_at + duration_minutes.minutes
    booked_table_ids = Reservation.confirmed.overlapping(starts_at, ends_at).select(:dining_table_id)

    active.where(location: location)
          .seating_at_least(party_size)
          .where.not(id: booked_table_ids)
          .order(:capacity, :number)
  end
end