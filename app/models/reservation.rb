class Reservation < ApplicationRecord
  DEFAULT_DURATION_MINUTES = 120
  LOCK_DURATION = 5.minutes

  belongs_to :user, optional: true   # erfassender Mitarbeiter (nur bei manueller Erfassung)
  belongs_to :dining_table
  has_one :location, through: :dining_table

  has_secure_token :confirmation_code

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" },
       default: :pending, validate: true

  normalizes :guest_email, with: ->(email) { email.strip.downcase }

  before_validation :set_ends_at

  validates :starts_at, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :party_size, presence: true,
                         numericality: { only_integer: true, greater_than: 0 }
  validate :starts_at_in_future, on: :create
  validate :party_size_fits_table

  # Kontaktdaten sind erst beim Abschluss Pflicht: Die Sperre startet schon
  # bei der Tischwahl, bevor der Gast seine Daten eingegeben hat.
  with_options unless: :pending? do
    validates :guest_name, presence: true
    validates :guest_email, presence: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  end

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