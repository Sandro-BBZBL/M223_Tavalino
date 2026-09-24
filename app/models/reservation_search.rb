# Suchformular für freie Tische (kein DB-Model): Datum, Uhrzeit, Personenzahl
# an einem Standort. Liefert freie Tische und Alternativvorschläge.
class ReservationSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  TIME_SLOTS = (11..21).flat_map { |hour| [ format("%02d:00", hour), format("%02d:30", hour) ] }.freeze
  MAX_PARTY_SIZE = 12
  # Versatz in Minuten, nach Nähe zur Wunschzeit sortiert
  ALTERNATIVE_OFFSETS = [ -30, 30, -60, 60, -90, 90, -120, 120 ].freeze

  Alternative = Struct.new(:location, :starts_at, :dining_table, keyword_init: true)

  attribute :date, :date, default: -> { Date.current.tomorrow }
  attribute :time, :string, default: "19:00"
  attribute :party_size, :integer, default: 2

  attr_reader :location

  validates :date, presence: { message: "Bitte ein Datum angeben." }
  validates :time, inclusion: { in: TIME_SLOTS, message: "Bitte eine Uhrzeit aus der Liste wählen." }
  validates :party_size,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_PARTY_SIZE,
                            message: "Bitte eine Personenzahl zwischen 1 und #{MAX_PARTY_SIZE} angeben." }
  validate :starts_at_in_future

  def initialize(location:, attributes: {})
    super(attributes)
    @location = location
  end

  def starts_at
    return unless date && TIME_SLOTS.include?(time)

    hour, minute = time.split(":").map(&:to_i)
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end

  # Freie Tische am gewünschten Standort (nur sinnvoll, wenn valid?)
  def tables
    DiningTable.available_for(location: location, starts_at: starts_at, party_size: party_size)
  end

  # Nächstliegende freie Zeiten am selben Standort, danach derselbe Zeitpunkt
  # an den anderen Standorten.
  def self.alternatives_for(location:, starts_at:, party_size:, limit: 3, locations: Location.all)
    same_location = []
    ALTERNATIVE_OFFSETS.each do |offset|
      time = starts_at + offset.minutes
      next if time <= Time.current

      table = DiningTable.available_for(location: location, starts_at: time, party_size: party_size).first
      same_location << Alternative.new(location: location, starts_at: time, dining_table: table) if table
      break if same_location.size >= limit
    end

    other_locations = locations.where.not(id: location.id).order(:name).filter_map do |other|
      table = DiningTable.available_for(location: other, starts_at: starts_at, party_size: party_size).first
      Alternative.new(location: other, starts_at: starts_at, dining_table: table) if table
    end

    same_location + other_locations
  end

  private

  def starts_at_in_future
    return unless starts_at

    errors.add(:base, "Der gewählte Zeitpunkt muss in der Zukunft liegen.") if starts_at <= Time.current
  end
end