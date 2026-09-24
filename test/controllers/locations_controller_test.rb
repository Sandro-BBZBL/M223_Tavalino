require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
    @zurich = locations(:zurich)
  end

  def search_params(overrides = {})
    { search: { date: @dinner.starts_at.to_date.to_s, time: "19:00", party_size: 2 }.merge(overrides) }
  end

  test "shows the search form without login" do
    get location_path(@zurich)

    assert_response :success
    assert_select "form"
    assert_select "[data-table-id]", count: 0
  end

  test "lists only free tables" do
    get location_path(@zurich), params: search_params

    assert_response :success
    assert_select "[data-table-id='#{dining_tables(:zurich_2).id}']"
    assert_select "[data-table-id='#{dining_tables(:zurich_1).id}']", count: 0
    assert_select "[data-table-id='#{dining_tables(:zurich_inactive).id}']", count: 0
  end

  test "suggests alternatives if no table is free" do
    get location_path(@zurich), params: search_params(party_size: 3)

    assert_response :success
    assert_select "[data-table-id]", count: 0
    assert_select "[data-alternatives]"
  end

  test "rejects a date in the past with a clear message" do
    get location_path(@zurich), params: search_params(date: Date.current.yesterday.to_s)

    assert_response :success
    assert_select "[role=alert]", /Zukunft/
    assert_select "[data-table-id]", count: 0
  end

  test "unknown location returns 404" do
    get location_path(id: 0)
    assert_response :not_found
  end
end