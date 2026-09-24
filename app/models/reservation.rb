class Reservation < ApplicationRecord
  DEFAULT_DURATION_MINUTES = 120
  CANCELLATION_DEADLINE = 2.hours

  belongs_to :user, optional: true   # erfassender Mitarbeiter (nur bei manueller Erfassung)
  belongs_to :dining_table
  has_one :location, through: :dining_table

  has_secure_token :confirmation_code

  # Optimistic Locking: Rails nutzt die Spalte lock_version automatisch und wirft
  # ActiveRecord::StaleObjectError, wenn jemand anderes zuerst gespeichert hat.
  enum :status, { confirmed: "confirmed", cancelled: "cancelled" },
       default: :confirmed, validate: true

  normalizes :guest_email, with: ->(email) { email.strip.downcase }

  # Zwei Zeiträume überschneiden sich, wenn: Beginn A < Ende B UND Ende A > Beginn B
  scope :overlapping, lambda { |starts_at, ends_at|
    where("reservations.starts_at < ? AND reservations.ends_at > ?", ends_at, starts_at)
  }

  # Filter für die Mitarbeiter-Übersicht
  scope :at_location, lambda { |location_id|
    joins(:dining_table).where(dining_tables: { location_id: location_id })
  }
  scope :on_date, ->(date) { where(starts_at: date.in_time_zone.all_day) }
  scope :from_today, -> { where("reservations.starts_at >= ?", Time.current.beginning_of_day) }

  # Gast findet seine Reservation mit Code + E-Mail. Gibt nil zurück, wenn
  # eines von beiden nicht passt (ohne zu verraten, welches).
  def self.find_for_guest(code, email)
    return if code.blank? || email.blank?

    reservation = find_by(confirmation_code: code.to_s.strip)
    return unless reservation

    given_email = normalize_value_for(:guest_email, email.to_s)
    reservation if ActiveSupport::SecurityUtils.secure_compare(reservation.guest_email.to_s, given_email)
  end

  before_validation :set_ends_at

  validates :starts_at, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :party_size, presence: true,
                         numericality: { only_integer: true, greater_than: 0 }
  # Neue Reservationen und verschobene Termine müssen in der Zukunft liegen.
  # Andere Änderungen (Telefon, Stornierung) an vergangenen Terminen bleiben möglich.
  validate :starts_at_in_future, if: -> { new_record? || will_save_change_to_starts_at? }
  validate :party_size_fits_table
  validate :dining_table_is_active, if: :table_changed?
  validate :no_overlapping_reservation, if: :availability_relevant_change?

  validates :guest_name, presence: true
  validates :guest_email, presence: true,
                          format: { with: URI::MailTo::EMAIL_REGEXP }

  # Bucht die Reservation: Tisch sperren, Überschneidung prüfen, speichern.
  # Alles in EINER kurzen Transaktion, damit parallele Buchungen auf denselben
  # Tisch nacheinander laufen. Gibt true/false zurück (Fehler stehen in #errors).
  def book
    transaction do
      dining_table.lock!
      save
    end
  end

  # Änderung durch Mitarbeiter/Admins aus dem Bearbeiten-Formular.
  # attributes enthält die lock_version, die das Formular beim Öffnen hatte.
  # Wurde die Reservation seither geändert, wird ActiveRecord::StaleObjectError
  # geworfen und NICHTS gespeichert. Ansonsten wie beim Buchen: (neuen) Tisch
  # sperren, prüfen, speichern. Gibt true/false zurück.
  def update_with_lock(attributes)
    transaction do
      assign_attributes(attributes)
      # Formular-Version veraltet? Dann sofort abbrechen, noch vor den Validierungen.
      raise ActiveRecord::StaleObjectError.new(self, "update") if lock_version_changed?

      dining_table&.lock!
      save
    end
  end

  # true, wenn der Fehler daher kommt, dass der Zeitraum bereits vergeben ist
  def slot_taken?
    errors.of_kind?(:base, :taken)
  end

  def cancellable?
    confirmed? && starts_at >= CANCELLATION_DEADLINE.from_now
  end

  # Storniert die Reservation. Gäste sind an die 2-Stunden-Frist gebunden,
  # Mitarbeiter/Admins nicht (respecting_deadline: false).
  def cancel(respecting_deadline: true)
    if cancelled?
      errors.add(:base, "Diese Reservation ist bereits storniert.")
      false
    elsif respecting_deadline && !cancellable?
      errors.add(:base, "Eine Stornierung ist nur bis 2 Stunden vor dem Termin möglich.")
      false
    else
      update(status: :cancelled)
    end
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

  def table_changed?
    new_record? || will_save_change_to_dining_table_id?
  end

  def dining_table_is_active
    return unless dining_table
    errors.add(:dining_table, "ist deaktiviert und kann nicht reserviert werden") unless dining_table.active?
  end

  # Die Überschneidungsprüfung ist nur nötig, wenn sich etwas ändert, das die
  # Belegung betrifft. Stornierte Reservationen blockieren den Tisch nicht.
  def availability_relevant_change?
    confirmed? && starts_at && ends_at && dining_table &&
      (new_record? ||
        will_save_change_to_starts_at? ||
        will_save_change_to_ends_at? ||
        will_save_change_to_dining_table_id? ||
        will_save_change_to_status?)
  end

  def no_overlapping_reservation
    conflict = Reservation.confirmed
                          .where(dining_table_id: dining_table_id)
                          .where.not(id: id)
                          .overlapping(starts_at, ends_at)
                          .exists?
    return unless conflict

    errors.add(:base, :taken, message: "Der gewünschte Zeitraum ist an diesem Tisch bereits vergeben.")
  end
end