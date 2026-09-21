require "test_helper"

class ReservationTest < ActiveSupport::TestCase
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
end