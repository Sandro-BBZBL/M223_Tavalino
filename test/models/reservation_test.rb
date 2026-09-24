require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
  end

  def build_reservation(table: dining_tables(:zurich_1), starts_at: @dinner.starts_at, party_size: 2)
    Reservation.new(
      dining_table: table,
      starts_at: starts_at,
      party_size: party_size,
      guest_name: "Bob Gast",
      guest_email: "bob@example.com"
    )
  end

  test "new reservations are confirmed by default" do
    reservation = Reservation.new
    assert reservation.confirmed?
  end

  test "ends_at is derived from starts_at and duration" do
    reservation = reservations(:zurich_dinner)
    reservation.valid?
    assert_equal reservation.starts_at + 120.minutes, reservation.ends_at
  end

  test "party size may not exceed table capacity" do
    reservation = reservations(:zurich_dinner)
    reservation.party_size = reservation.dining_table.capacity + 1
    assert_not reservation.valid?
    assert reservation.errors[:party_size].any?
  end

  test "optimistic locking rejects a stale update" do
    first  = Reservation.find(reservations(:zurich_dinner).id)
    second = Reservation.find(reservations(:zurich_dinner).id)

    first.update!(party_size: 3)

    assert_raises(ActiveRecord::StaleObjectError) do
      second.update!(party_size: 4)
    end
    assert_equal 3, reservations(:zurich_dinner).reload.party_size
  end

  # --- Überschneidungen -------------------------------------------------------

  test "identical time slot on the same table is rejected" do
    reservation = build_reservation
    assert_not reservation.valid?
    assert reservation.slot_taken?
  end

  test "partially overlapping slot (starts during existing) is rejected" do
    reservation = build_reservation(starts_at: @dinner.starts_at + 1.hour)
    assert_not reservation.valid?
    assert reservation.slot_taken?
  end

  test "partially overlapping slot (ends during existing) is rejected" do
    reservation = build_reservation(starts_at: @dinner.starts_at - 1.hour)
    assert_not reservation.valid?
    assert reservation.slot_taken?
  end

  test "back-to-back reservations do not overlap" do
    assert build_reservation(starts_at: @dinner.ends_at).valid?
    assert build_reservation(starts_at: @dinner.starts_at - 2.hours).valid?
  end

  test "same time on another table is allowed" do
    assert build_reservation(table: dining_tables(:zurich_2)).valid?
  end

  test "cancelled reservations do not block the table" do
    @dinner.update!(status: :cancelled)
    assert build_reservation.valid?
  end

  test "editing a reservation does not conflict with itself" do
    assert @dinner.update(party_size: 3)
  end

  test "inactive tables cannot be reserved" do
    reservation = build_reservation(table: dining_tables(:zurich_inactive))
    assert_not reservation.valid?
    assert reservation.errors[:dining_table].any?
  end

  # --- Buchung (Transaktion) --------------------------------------------------

  test "book saves a free slot" do
    reservation = build_reservation(table: dining_tables(:zurich_2))
    assert_difference "Reservation.count", 1 do
      assert reservation.book
    end
    assert reservation.confirmation_code.present?
  end

  test "book rejects the second booking of the same slot" do
    first  = build_reservation(table: dining_tables(:zurich_2))
    second = build_reservation(table: dining_tables(:zurich_2), starts_at: first.starts_at + 1.hour)

    assert first.book
    assert_no_difference "Reservation.count" do
      assert_not second.book
    end
    assert second.slot_taken?
  end

  # --- Stornierung ------------------------------------------------------------

  test "guest can cancel before the deadline" do
    assert @dinner.cancellable?
    assert @dinner.cancel
    assert @dinner.reload.cancelled?
  end

  test "guest cannot cancel less than 2 hours before the start" do
    travel_to(@dinner.starts_at - 1.hour) do
      assert_not @dinner.cancellable?
      assert_not @dinner.cancel
      assert @dinner.reload.confirmed?
    end
  end

  test "staff can cancel after the deadline" do
    travel_to(@dinner.starts_at - 1.hour) do
      assert @dinner.cancel(respecting_deadline: false)
      assert @dinner.reload.cancelled?
    end
  end

  test "an already cancelled reservation cannot be cancelled again" do
    @dinner.cancel
    assert_not @dinner.cancel
  end

  # --- Abruf durch den Gast ---------------------------------------------------

  test "find_for_guest finds a reservation by code and email" do
    assert_equal @dinner, Reservation.find_for_guest(@dinner.confirmation_code, "anna@example.com")
  end

  test "find_for_guest ignores case and whitespace of the email" do
    assert_equal @dinner, Reservation.find_for_guest(@dinner.confirmation_code, "  Anna@Example.COM ")
  end

  test "find_for_guest returns nil for wrong or missing input" do
    assert_nil Reservation.find_for_guest(@dinner.confirmation_code, "andere@example.com")
    assert_nil Reservation.find_for_guest("falscher-code", "anna@example.com")
    assert_nil Reservation.find_for_guest("", "")
    assert_nil Reservation.find_for_guest(nil, nil)
  end

  # --- Bearbeiten durch Mitarbeiter (Optimistic Locking) ----------------------

  test "update_with_lock saves a change with the current version" do
    assert @dinner.update_with_lock(party_size: 3, lock_version: @dinner.lock_version)

    @dinner.reload
    assert_equal 3, @dinner.party_size
    assert_equal 1, @dinner.lock_version
  end

  test "update_with_lock raises on a stale version and saves nothing" do
    old_version = @dinner.lock_version
    Reservation.find(@dinner.id).update!(party_size: 3) # jemand anderes war schneller

    reservation = Reservation.find(@dinner.id)
    assert_raises(ActiveRecord::StaleObjectError) do
      reservation.update_with_lock(party_size: 4, lock_version: old_version)
    end

    assert_equal 3, @dinner.reload.party_size
  end

  test "update_with_lock reports a stale version before validation errors" do
    old_version = @dinner.lock_version
    Reservation.find(@dinner.id).update!(party_size: 3)

    reservation = Reservation.find(@dinner.id)
    assert_raises(ActiveRecord::StaleObjectError) do
      reservation.update_with_lock(party_size: 99, lock_version: old_version) # wäre auch ungültig
    end
  end

  test "update_with_lock rejects moving onto an occupied slot" do
    other = Reservation.create!(dining_table: dining_tables(:zurich_2), starts_at: @dinner.starts_at,
                                party_size: 2, guest_name: "Carl Gast", guest_email: "carl@example.com")

    assert_not other.update_with_lock(dining_table_id: dining_tables(:zurich_1).id, lock_version: other.lock_version)
    assert other.slot_taken?
    assert_equal dining_tables(:zurich_2), other.reload.dining_table
  end

  test "update_with_lock rejects moving a reservation into the past" do
    assert_not @dinner.update_with_lock(starts_at: 1.hour.ago, lock_version: @dinner.lock_version)
    assert @dinner.errors[:starts_at].any?
  end

  test "past reservations can still be edited without moving them" do
    @dinner.update_columns(starts_at: 2.days.ago, ends_at: 2.days.ago + 2.hours)

    assert @dinner.update_with_lock(guest_phone: "079 111 22 33", lock_version: @dinner.lock_version)
    assert_equal "079 111 22 33", @dinner.reload.guest_phone
  end

  test "staff can cancel a reservation after the guest deadline" do
    travel_to(@dinner.starts_at - 30.minutes) do
      assert @dinner.cancel(respecting_deadline: false)
    end
  end
end