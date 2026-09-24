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
end