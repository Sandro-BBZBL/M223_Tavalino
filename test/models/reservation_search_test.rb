require "test_helper"

class ReservationSearchTest < ActiveSupport::TestCase
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
    @zurich = locations(:zurich)
    @luzern = locations(:luzern)
  end

  def search(overrides = {})
    attributes = { date: @dinner.starts_at.to_date, time: "19:00", party_size: 2 }.merge(overrides)
    ReservationSearch.new(location: @zurich, attributes: attributes)
  end

  test "valid search" do
    assert search.valid?
  end

  test "starts_at combines date and time" do
    assert_equal @dinner.starts_at, search.starts_at
  end

  test "date is required" do
    assert_not search(date: "").valid?
  end

  test "time must be one of the offered slots" do
    assert_not search(time: "25:00").valid?
    assert_not search(time: "abc").valid?
  end

  test "party size must be between 1 and the maximum" do
    assert_not search(party_size: 0).valid?
    assert_not search(party_size: ReservationSearch::MAX_PARTY_SIZE + 1).valid?
    assert_not search(party_size: "").valid?
  end

  test "date in the past is rejected" do
    assert_not search(date: Date.current.yesterday).valid?
  end

  test "tables returns only free, fitting tables" do
    tables = search.tables
    assert_includes tables, dining_tables(:zurich_2)
    assert_not_includes tables, dining_tables(:zurich_1)
  end

  test "alternatives suggest close times at the same location first" do
    alternatives = ReservationSearch.alternatives_for(location: @zurich, starts_at: @dinner.starts_at, party_size: 2)

    assert_equal @dinner.starts_at - 30.minutes, alternatives.first.starts_at
    assert_equal @zurich, alternatives.first.location
  end

  test "alternatives include other locations at the wished time" do
    alternatives = ReservationSearch.alternatives_for(location: @zurich, starts_at: @dinner.starts_at, party_size: 2)

    luzern = alternatives.find { |alt| alt.location == @luzern }
    assert luzern
    assert_equal @dinner.starts_at, luzern.starts_at
  end

  test "alternatives are never in the past" do
    soon = 40.minutes.from_now
    alternatives = ReservationSearch.alternatives_for(location: @zurich, starts_at: soon, party_size: 2)

    assert alternatives.all? { |alt| alt.starts_at > Time.current }
  end

  test "alternatives at other locations respect the allowed locations" do
    alternatives = ReservationSearch.alternatives_for(location: @zurich, starts_at: @dinner.starts_at, party_size: 2,
                                                      locations: Location.where(id: @zurich.id))

    assert alternatives.any?
    assert alternatives.none? { |alt| alt.location == @luzern }
  end
end