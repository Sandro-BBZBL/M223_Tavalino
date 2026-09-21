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
end