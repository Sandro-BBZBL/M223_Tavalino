class Location < ApplicationRecord
  has_many :dining_tables, dependent: :restrict_with_error
  has_many :user_locations, dependent: :destroy
  has_many :users, through: :user_locations

  validates :name, presence: true, uniqueness: true
  validates :address, presence: true
end