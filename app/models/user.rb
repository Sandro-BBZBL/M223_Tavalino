class User < ApplicationRecord
  enum :role, { guest: "guest", staff: "staff", admin: "admin" },
       default: :guest, validate: true

  has_many :reservations, dependent: :restrict_with_error
  has_many :user_locations, dependent: :destroy
  has_many :locations, through: :user_locations

  validates :name, presence: true
  # E-Mail-Normalisierung, Passwortregeln und has_secure_password folgen in Aufgabe 2
end