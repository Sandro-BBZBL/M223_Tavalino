class User < ApplicationRecord
  EMAIL_CONFIRMATION_EXPIRY = 24.hours

  has_secure_password

  # Nur Mitarbeiter und Admins haben ein Konto. Gäste reservieren ohne Konto.
  enum :role, { staff: "staff", admin: "admin" },
       default: :staff, validate: true

  has_many :reservations, dependent: :restrict_with_error
  has_many :user_locations, dependent: :destroy
  has_many :locations, through: :user_locations

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :unconfirmed_email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true

  validates :unconfirmed_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :unconfirmed_email_available

  def admin?
    role == "admin"
  end

  # Bereitet die E-Mail-Änderung vor (speichert nicht)
  def stage_email_change(new_email)
    assign_attributes(
      unconfirmed_email: new_email,
      email_confirmation_token: SecureRandom.urlsafe_base64(32),
      email_confirmation_sent_at: Time.current
    )
  end

  # Übernimmt die neue Adresse, falls der Link noch gültig ist
  def confirm_email_change
    return false if unconfirmed_email.blank?
    return false if email_confirmation_sent_at < EMAIL_CONFIRMATION_EXPIRY.ago

    update(
      email_address: unconfirmed_email,
      unconfirmed_email: nil,
      email_confirmation_token: nil,
      email_confirmation_sent_at: nil
    )
  end

  private

  def unconfirmed_email_available
    return if unconfirmed_email.blank?

    if unconfirmed_email == email_address
      errors.add(:unconfirmed_email, "ist bereits deine aktuelle Adresse")
    elsif User.where.not(id: id).exists?(email_address: unconfirmed_email)
      errors.add(:unconfirmed_email, "ist bereits vergeben")
    end
  end
end