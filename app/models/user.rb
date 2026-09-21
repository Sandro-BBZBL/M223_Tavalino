class User < ApplicationRecord
  has_secure_password

  enum :role, { staff: "staff", admin: "admin" },
       default: :guest, validate: true

  has_many :reservations, dependent: :restrict_with_error
  has_many :user_locations, dependent: :destroy
  has_many :locations, through: :user_locations

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
end