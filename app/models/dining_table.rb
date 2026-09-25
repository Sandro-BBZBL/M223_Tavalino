class DiningTable < ApplicationRecord
  belongs_to :location
  has_many :reservations, dependent: :restrict_with_error

  validates :number, presence: true,
                     numericality: { only_integer: true, greater_than: 0 },
                     uniqueness: { scope: :location_id }
  validates :capacity, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }
  validate :capacity_covers_upcoming_reservations, if: :capacity_changed_on_existing_table?
  validate :no_upcoming_reservations_when_deactivating, if: :being_deactivated?

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

  # Anzahl künftiger, bestätigter Reservationen je Tisch (Verwaltungsliste): { tisch_id => anzahl }
  def self.upcoming_reservation_counts(table_ids)
    Reservation.confirmed
               .where(dining_table_id: table_ids)
               .where("reservations.starts_at > ?", Time.current)
               .group(:dining_table_id)
               .count
  end

  def upcoming_reservations
    reservations.confirmed.where("reservations.starts_at > ?", Time.current)
  end

  private

  def capacity_changed_on_existing_table?
    persisted? && will_save_change_to_capacity?
  end

  def being_deactivated?
    persisted? && will_save_change_to_active? && !active?
  end

  # Die Kapazität muss die Personenzahl bestehender künftiger Reservationen abdecken
  def capacity_covers_upcoming_reservations
    return unless capacity.to_i.positive?

    too_big = upcoming_reservations.where("reservations.party_size > ?", capacity).count
    return if too_big.zero?

    errors.add(:base, "Die Kapazität ist zu klein: #{too_big} künftige Reservation(en) haben mehr Personen.")
  end

  # Ein Tisch mit künftigen Reservationen wird erst deaktiviert, wenn diese verschoben oder storniert sind
  def no_upcoming_reservations_when_deactivating
    count = upcoming_reservations.count
    return if count.zero?

    errors.add(:base, "Der Tisch kann nicht deaktiviert werden: Es bestehen noch #{count} künftige " \
                      "Reservation(en). Bitte zuerst verschieben oder stornieren.")
  end
end