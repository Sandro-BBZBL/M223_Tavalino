require "test_helper"

class DiningTableTest < ActiveSupport::TestCase
  setup do
    # zurich_dinner belegt zurich_1 in 3 Tagen von 19:00 bis 21:00
    @dinner = reservations(:zurich_dinner)
    @zurich = locations(:zurich)
  end

  def available(starts_at:, party_size:)
    DiningTable.available_for(location: @zurich, starts_at: starts_at, party_size: party_size)
  end

  test "booked table is not available in the same slot" do
    tables = available(starts_at: @dinner.starts_at, party_size: 2)
    assert_includes tables, dining_tables(:zurich_2)
    assert_not_includes tables, dining_tables(:zurich_1)
  end

  test "table is not available in an overlapping slot" do
    tables = available(starts_at: @dinner.starts_at + 1.hour, party_size: 2)
    assert_not_includes tables, dining_tables(:zurich_1)
  end

  test "table is available again after the reservation ends" do
    tables = available(starts_at: @dinner.ends_at, party_size: 2)
    assert_includes tables, dining_tables(:zurich_1)
  end

  test "tables that are too small are excluded" do
    tables = available(starts_at: @dinner.starts_at + 1.day, party_size: 3)
    assert_includes tables, dining_tables(:zurich_1)
    assert_not_includes tables, dining_tables(:zurich_2)
  end

  test "inactive tables and other locations are excluded" do
    tables = available(starts_at: @dinner.starts_at + 1.day, party_size: 2)
    assert_not_includes tables, dining_tables(:zurich_inactive)
    assert_not_includes tables, dining_tables(:luzern_1)
  end

  test "smallest fitting table comes first" do
    tables = available(starts_at: @dinner.starts_at + 1.day, party_size: 2).to_a
    assert_equal [ dining_tables(:zurich_2), dining_tables(:zurich_1) ], tables
  end

  test "cancelled reservations free the table" do
    @dinner.update!(status: :cancelled)
    tables = available(starts_at: @dinner.starts_at, party_size: 2)
    assert_includes tables, dining_tables(:zurich_1)
  end

  test "returns nothing if no table fits" do
    tables = available(starts_at: @dinner.starts_at, party_size: 3)
    assert_empty tables
  end

  # --- Tischverwaltung (Admin) --------------------------------------------------

  test "number and capacity are required and must be positive" do
    table = DiningTable.new(location: @zurich)
    assert_not table.valid?
    assert table.errors[:number].any?
    assert table.errors[:capacity].any?

    table.number = 0
    table.capacity = -1
    assert_not table.valid?
  end

  test "number must be unique within the location but not across locations" do
    duplicate = DiningTable.new(location: @zurich, number: dining_tables(:zurich_1).number, capacity: 2)
    assert_not duplicate.valid?

    # Nummer 42 ist an keinem der beiden Standorte vergeben
    other_location = DiningTable.new(location: locations(:luzern), number: 42, capacity: 2)
    assert other_location.valid?
  end

  test "reducing capacity below an upcoming reservation's party size is rejected" do
    table = dining_tables(:zurich_2) # Kapazität 2, noch ohne Reservation
    Reservation.create!(dining_table: table, starts_at: 2.days.from_now, party_size: 2,
                        guest_name: "Gast", guest_email: "gast@example.com")

    table.capacity = 1
    assert_not table.valid?
    assert table.errors[:base].any? { |msg| msg.include?("Kapazität ist zu klein") }
  end

  test "reducing capacity that still fits upcoming reservations is allowed" do
    table = dining_tables(:zurich_1) # Kapazität 4, zurich_dinner-Fixture hat 2 Personen
    table.capacity = 3
    assert table.valid?
  end

  test "capacity may be reduced when there are no upcoming reservations" do
    table = dining_tables(:zurich_2)
    table.capacity = 1
    assert table.valid?
  end

  test "a new table is not checked against upcoming reservations" do
    table = DiningTable.new(location: @zurich, number: 99, capacity: 1)
    assert table.valid?
  end

  test "deactivating a table with upcoming reservations is rejected" do
    table = dining_tables(:zurich_1) # hat die zurich_dinner-Fixture als künftige Reservation

    assert_not table.update(active: false)
    assert table.errors[:base].any? { |msg| msg.include?("kann nicht deaktiviert werden") }
    assert table.reload.active?
  end

  test "a table without upcoming reservations can be deactivated" do
    table = dining_tables(:zurich_2)

    assert table.update(active: false)
  end

  test "a deactivated table no longer accepts new reservations" do
    dining_tables(:zurich_2).update!(active: false)

    reservation = Reservation.new(dining_table: dining_tables(:zurich_2), starts_at: 2.days.from_now,
                                  party_size: 2, guest_name: "Gast", guest_email: "gast@example.com")
    assert_not reservation.valid?
  end

  test "upcoming_reservation_counts counts only confirmed, future reservations" do
    table = dining_tables(:zurich_2)
    Reservation.create!(dining_table: table, starts_at: 2.days.from_now, party_size: 2,
                        guest_name: "Gast", guest_email: "gast@example.com")
    # storniert & vergangen anlegen: erst gültig erstellen, dann Werte direkt setzen (umgeht die Validierungen)
    past_cancelled = Reservation.create!(dining_table: table, starts_at: 3.days.from_now, party_size: 2,
                                         guest_name: "Alt", guest_email: "alt@example.com")
    past_cancelled.update_columns(starts_at: 2.days.ago, status: "cancelled")

    counts = DiningTable.upcoming_reservation_counts([ table.id, dining_tables(:zurich_1).id ])

    assert_equal 1, counts.fetch(table.id, 0)
    assert_equal 1, counts.fetch(dining_tables(:zurich_1).id, 0) # zurich_dinner-Fixture
  end
end