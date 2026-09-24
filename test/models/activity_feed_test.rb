require "test_helper"

class ActivityFeedTest < ActiveSupport::TestCase
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
    @staff = users(:staff)
  end

  def as(user, &block)
    PaperTrail.request(whodunnit: user&.id&.to_s, &block)
  end

  def entries_for(reservation)
    ActivityFeed.new(reservation.versions.reorder(id: :desc)).entries
  end

  def latest_entry(reservation)
    entries_for(reservation).first
  end

  def new_reservation(overrides = {})
    Reservation.new({ dining_table: dining_tables(:zurich_2), starts_at: @dinner.starts_at + 1.day, party_size: 2,
                      guest_name: "Bob Gast", guest_email: "bob@example.com" }.merge(overrides))
  end

  def table_label(table)
    "#{table.location.name}, Tisch #{table.number}"
  end

  test "a guest booking is shown as booked by Gast" do
    reservation = new_reservation
    as(nil) { assert reservation.book }

    entry = latest_entry(reservation)
    assert_equal "Gast", entry.actor
    assert_equal "gebucht", entry.action
    assert_equal reservation.id, entry.reservation_id
    assert_equal reservation, entry.reservation
  end

  test "a reservation recorded by staff is shown with the staff member" do
    reservation = new_reservation(user: @staff)
    as(@staff) { assert reservation.book }

    entry = latest_entry(reservation)
    assert_equal @staff.name, entry.actor
    assert_equal "erfasst", entry.action
  end

  test "a new reservation lists its values without arrows and skips blank ones" do
    reservation = new_reservation(guest_phone: nil)
    as(nil) { reservation.book }

    lines = latest_entry(reservation).changes
    assert_includes lines, "Name: Bob Gast"
    assert_includes lines, "Personenzahl: 2"
    assert_includes lines, "Tisch: #{table_label(dining_tables(:zurich_2))}"
    assert lines.none? { |line| line.include?("→") }
    assert lines.none? { |line| line.start_with?("Telefon") }
  end

  test "the secret confirmation code never appears in the feed" do
    reservation = new_reservation
    as(nil) { reservation.book }

    text = entries_for(reservation).flat_map(&:changes).join(" ")
    assert reservation.confirmation_code.present?
    assert_not_includes text, reservation.confirmation_code
  end

  test "an update is shown as changed with old and new value" do
    as(@staff) { @dinner.update!(party_size: 3) }

    entry = latest_entry(@dinner)
    assert_equal "geändert", entry.action
    assert_equal @staff.name, entry.actor
    assert_equal [ "Personenzahl: 2 → 3" ], entry.changes
  end

  test "a cancellation is shown as cancelled with the status change" do
    as(@staff) { @dinner.cancel(respecting_deadline: false) }

    entry = latest_entry(@dinner)
    assert_equal "storniert", entry.action
    assert_includes entry.changes, "Status: bestätigt → storniert"
  end

  test "a cancellation by the guest is shown as cancelled by Gast" do
    as(nil) { @dinner.cancel }

    entry = latest_entry(@dinner)
    assert_equal "Gast", entry.actor
    assert_equal "storniert", entry.action
  end

  test "a table change shows both tables" do
    as(@staff) { @dinner.update!(dining_table: dining_tables(:zurich_2)) }

    expected = "Tisch: #{table_label(dining_tables(:zurich_1))} → #{table_label(dining_tables(:zurich_2))}"
    assert_includes latest_entry(@dinner).changes, expected
  end

  test "a moved time is shown formatted" do
    old_start = @dinner.starts_at
    as(@staff) { @dinner.update!(starts_at: old_start + 1.hour) }

    expected = "Zeitpunkt: #{old_start.strftime('%d.%m.%Y, %H:%M')} → #{(old_start + 1.hour).strftime('%d.%m.%Y, %H:%M')}"
    assert_includes latest_entry(@dinner).changes, expected
  end

  test "technical fields are not shown" do
    as(@staff) { @dinner.update!(party_size: 3) }

    text = latest_entry(@dinner).changes.join(" ")
    assert_no_match(/lock_version|updated_at|ends_at|user_id/, text)
  end

  test "an unknown actor is shown neutrally" do
    PaperTrail.request(whodunnit: "999999") { @dinner.update!(party_size: 3) }

    assert_equal "Unbekannter Benutzer", latest_entry(@dinner).actor
  end

  test "entries keep the order of the given versions" do
    as(@staff) do
      @dinner.update!(party_size: 3)
      @dinner.update!(party_size: 4)
    end

    lines = entries_for(@dinner).map(&:changes)
    assert_equal [ [ "Personenzahl: 3 → 4" ], [ "Personenzahl: 2 → 3" ] ], lines
  end
end