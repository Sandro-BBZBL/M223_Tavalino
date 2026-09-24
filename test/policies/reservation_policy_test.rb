require "test_helper"

class ReservationPolicyTest < ActiveSupport::TestCase
  setup do
    @zurich_reservation = reservations(:zurich_dinner)
    @luzern_reservation = reservations(:luzern_lunch)

    @admin = users(:admin)
    @staff_zurich = users(:staff)
    @staff_luzern = users(:staff_luzern)
    @staff_unassigned = users(:staff_unassigned)
  end

  def policy(user, reservation = Reservation)
    ReservationPolicy.new(user, reservation)
  end

  def visible_to(user)
    ReservationPolicy::Scope.new(user, Reservation).resolve.to_a
  end

  # --- index? -----------------------------------------------------------------

  test "every signed in user may open the overview" do
    assert policy(@admin).index?
    assert policy(@staff_zurich).index?
    assert policy(@staff_unassigned).index?
  end

  test "visitors may not open the overview" do
    assert_not policy(nil).index?
  end

  # --- show? ------------------------------------------------------------------

  test "admin may see reservations of every location" do
    assert policy(@admin, @zurich_reservation).show?
    assert policy(@admin, @luzern_reservation).show?
  end

  test "staff may only see reservations of their own locations" do
    assert policy(@staff_zurich, @zurich_reservation).show?
    assert_not policy(@staff_zurich, @luzern_reservation).show?

    assert policy(@staff_luzern, @luzern_reservation).show?
    assert_not policy(@staff_luzern, @zurich_reservation).show?
  end

  test "staff without a location may see nothing" do
    assert_not policy(@staff_unassigned, @zurich_reservation).show?
    assert_not policy(@staff_unassigned, @luzern_reservation).show?
  end

  test "visitors may not see reservations" do
    assert_not policy(nil, @zurich_reservation).show?
  end

  # --- Scope ------------------------------------------------------------------

  test "scope for admin contains all reservations" do
    assert_equal Reservation.count, visible_to(@admin).size
  end

  test "scope for staff contains only reservations of their locations" do
    assert_equal [ @zurich_reservation ], visible_to(@staff_zurich)
    assert_equal [ @luzern_reservation ], visible_to(@staff_luzern)
  end

  test "scope for staff with several locations combines them" do
    UserLocation.create!(user: @staff_zurich, location: locations(:luzern))

    assert_equal [ @zurich_reservation, @luzern_reservation ].sort_by(&:id), visible_to(@staff_zurich.reload).sort_by(&:id)
  end

  test "scope for staff without a location is empty" do
    assert_empty visible_to(@staff_unassigned)
  end

  test "scope for visitors is empty" do
    assert_empty visible_to(nil)
  end

  # --- update? / cancel? -------------------------------------------------------

  test "admin may update and cancel every reservation" do
    [ @zurich_reservation, @luzern_reservation ].each do |reservation|
      assert policy(@admin, reservation).update?
      assert policy(@admin, reservation).edit?
      assert policy(@admin, reservation).cancel?
    end
  end

  test "staff may only update and cancel reservations of their own locations" do
    assert policy(@staff_zurich, @zurich_reservation).update?
    assert policy(@staff_zurich, @zurich_reservation).cancel?

    assert_not policy(@staff_zurich, @luzern_reservation).update?
    assert_not policy(@staff_zurich, @luzern_reservation).edit?
    assert_not policy(@staff_zurich, @luzern_reservation).cancel?
  end

  test "staff without a location may not update or cancel" do
    assert_not policy(@staff_unassigned, @zurich_reservation).update?
    assert_not policy(@staff_unassigned, @zurich_reservation).cancel?
  end

  test "visitors may not update or cancel" do
    assert_not policy(nil, @zurich_reservation).update?
    assert_not policy(nil, @zurich_reservation).cancel?
  end

  # --- create? (manuell erfassen) ----------------------------------------------

  test "every signed in user may open the empty form" do
    assert policy(@admin, Reservation.new).create?
    assert policy(@staff_zurich, Reservation.new).new?
    assert policy(@staff_unassigned, Reservation.new).create?
  end

  test "visitors may not create reservations" do
    assert_not policy(nil, Reservation.new).create?
    assert_not policy(nil, Reservation.new(dining_table: dining_tables(:zurich_1))).create?
  end

  test "admin may create reservations on tables of every location" do
    assert policy(@admin, Reservation.new(dining_table: dining_tables(:zurich_1))).create?
    assert policy(@admin, Reservation.new(dining_table: dining_tables(:luzern_1))).create?
  end

  test "staff may only create reservations on tables of their own locations" do
    assert policy(@staff_zurich, Reservation.new(dining_table: dining_tables(:zurich_1))).create?
    assert_not policy(@staff_zurich, Reservation.new(dining_table: dining_tables(:luzern_1))).create?
    assert_not policy(@staff_luzern, Reservation.new(dining_table: dining_tables(:zurich_1))).create?
  end

  test "staff without a location may not create reservations on any table" do
    assert_not policy(@staff_unassigned, Reservation.new(dining_table: dining_tables(:zurich_1))).create?
  end
end