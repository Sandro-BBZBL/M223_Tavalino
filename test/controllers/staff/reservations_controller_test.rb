require "test_helper"

class Staff::ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @zurich_reservation = reservations(:zurich_dinner)   # Zürich, in 3 Tagen 19:00
    @luzern_reservation = reservations(:luzern_lunch)    # Luzern, in 4 Tagen 12:00
  end

  def row_for(reservation)
    "tr[data-reservation-id='#{reservation.id}']"
  end

  # --- Anmeldung --------------------------------------------------------------

  test "visitors are redirected to the login" do
    get staff_reservations_path
    assert_redirected_to new_user_session_path

    get staff_reservation_path(@zurich_reservation)
    assert_redirected_to new_user_session_path
  end

  # --- Übersicht --------------------------------------------------------------

  test "admin sees reservations of all locations" do
    sign_in_as users(:admin)

    get staff_reservations_path

    assert_response :success
    assert_select row_for(@zurich_reservation)
    assert_select row_for(@luzern_reservation)
  end

  test "staff sees only reservations of their own location" do
    sign_in_as users(:staff)

    get staff_reservations_path

    assert_response :success
    assert_select row_for(@zurich_reservation)
    assert_select row_for(@luzern_reservation), count: 0
  end

  test "staff without a location sees a hint and no reservations" do
    sign_in_as users(:staff_unassigned)

    get staff_reservations_path

    assert_response :success
    assert_match "kein Standort", response.body
    assert_select "table", count: 0
  end

  test "overview is sorted by time" do
    sign_in_as users(:admin)

    get staff_reservations_path

    ids = css_select("tr[data-reservation-id]").map { |row| row["data-reservation-id"].to_i }
    assert_equal [ @zurich_reservation.id, @luzern_reservation.id ], ids
  end

  test "overview can be filtered by location" do
    sign_in_as users(:admin)

    get staff_reservations_path, params: { location_id: locations(:luzern).id }

    assert_select row_for(@luzern_reservation)
    assert_select row_for(@zurich_reservation), count: 0
  end

  test "staff cannot see foreign reservations via a location filter" do
    sign_in_as users(:staff)

    get staff_reservations_path, params: { location_id: locations(:luzern).id }

    assert_response :success
    assert_select "tr[data-reservation-id]", count: 0
  end

  test "overview can be filtered by date" do
    sign_in_as users(:admin)

    get staff_reservations_path, params: { date: @luzern_reservation.starts_at.to_date.to_s }

    assert_select row_for(@luzern_reservation)
    assert_select row_for(@zurich_reservation), count: 0
  end

  test "past reservations are hidden by default but visible by date" do
    sign_in_as users(:admin)
    @zurich_reservation.update_columns(starts_at: 2.days.ago, ends_at: 2.days.ago + 2.hours)

    get staff_reservations_path
    assert_select row_for(@zurich_reservation), count: 0

    get staff_reservations_path, params: { date: @zurich_reservation.starts_at.to_date.to_s }
    assert_select row_for(@zurich_reservation)
  end

  test "an invalid date filter is ignored" do
    sign_in_as users(:admin)

    get staff_reservations_path, params: { date: "kein-datum" }

    assert_response :success
    assert_select row_for(@zurich_reservation)
  end

  # --- Detail -----------------------------------------------------------------

  test "staff sees the details of a reservation of their location" do
    sign_in_as users(:staff)

    get staff_reservation_path(@zurich_reservation)

    assert_response :success
    assert_match "Anna Gast", response.body
    assert_match "anna@example.com", response.body
  end

  test "staff cannot open a reservation of a foreign location directly" do
    sign_in_as users(:staff)

    get staff_reservation_path(@luzern_reservation)

    assert_redirected_to root_path
    follow_redirect!
    assert_match "keine Berechtigung", response.body
  end

  test "staff without a location cannot open any reservation" do
    sign_in_as users(:staff_unassigned)

    get staff_reservation_path(@zurich_reservation)

    assert_redirected_to root_path
  end

  test "admin can open any reservation" do
    sign_in_as users(:admin)

    get staff_reservation_path(@luzern_reservation)

    assert_response :success
    assert_match "Lena Luzern", response.body
  end

  # --- Navigation -------------------------------------------------------------

  test "staff does not see admin links" do
    sign_in_as users(:staff)

    get staff_reservations_path

    assert_select "a[href=?]", staff_reservations_path
    assert_select "a[href=?]", admin_users_path, count: 0
    assert_select "a[href=?]", admin_dashboard_path, count: 0
  end

  test "admin sees admin links" do
    sign_in_as users(:admin)

    get staff_reservations_path

    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", admin_dashboard_path
  end

  # --- Bearbeiten -------------------------------------------------------------

  def edit_params(reservation, overrides = {})
    { reservation: {
      dining_table_id: reservation.dining_table_id,
      starts_at: reservation.starts_at.strftime("%Y-%m-%dT%H:%M"),
      party_size: reservation.party_size,
      guest_name: reservation.guest_name,
      guest_email: reservation.guest_email,
      guest_phone: reservation.guest_phone.to_s,
      lock_version: reservation.lock_version
    }.merge(overrides) }
  end

  test "visitors cannot edit or update" do
    get edit_staff_reservation_path(@zurich_reservation)
    assert_redirected_to new_user_session_path

    patch staff_reservation_path(@zurich_reservation), params: edit_params(@zurich_reservation, party_size: 3)
    assert_redirected_to new_user_session_path
    assert_equal 2, @zurich_reservation.reload.party_size
  end

  test "staff sees the edit form with version and only own tables" do
    sign_in_as users(:staff)

    get edit_staff_reservation_path(@zurich_reservation)

    assert_response :success
    assert_select "input[name='reservation[lock_version]'][value='#{@zurich_reservation.lock_version}']"
    assert_select "option[value='#{dining_tables(:zurich_2).id}']"
    assert_select "option[value='#{dining_tables(:luzern_1).id}']", count: 0
    assert_select "option[value='#{dining_tables(:zurich_inactive).id}']", count: 0
  end

  test "staff cannot open the edit form of a foreign reservation" do
    sign_in_as users(:staff)

    get edit_staff_reservation_path(@luzern_reservation)

    assert_redirected_to root_path
  end

  test "staff updates a reservation of their location" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation), params: edit_params(@zurich_reservation, party_size: 3)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    @zurich_reservation.reload
    assert_equal 3, @zurich_reservation.party_size
    assert_equal 1, @zurich_reservation.lock_version
  end

  test "staff moves a reservation to another table of their location" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation),
          params: edit_params(@zurich_reservation, dining_table_id: dining_tables(:zurich_2).id)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    assert_equal dining_tables(:zurich_2), @zurich_reservation.reload.dining_table
  end

  test "staff cannot move a reservation to a table of a foreign location" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation),
          params: edit_params(@zurich_reservation, dining_table_id: dining_tables(:luzern_1).id)

    assert_response :not_found
    assert_equal dining_tables(:zurich_1), @zurich_reservation.reload.dining_table
  end

  test "staff cannot update a foreign reservation directly" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@luzern_reservation), params: edit_params(@luzern_reservation, guest_name: "Gehackt")

    assert_redirected_to root_path
    assert_equal "Lena Luzern", @luzern_reservation.reload.guest_name
  end

  test "admin can update reservations of any location" do
    sign_in_as users(:admin)

    patch staff_reservation_path(@luzern_reservation), params: edit_params(@luzern_reservation, guest_name: "Lena Neu")

    assert_redirected_to staff_reservation_path(@luzern_reservation)
    assert_equal "Lena Neu", @luzern_reservation.reload.guest_name
  end

  test "invalid data is rejected and nothing is saved" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation), params: edit_params(@zurich_reservation, party_size: 9)

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Kapazität/
    assert_equal 2, @zurich_reservation.reload.party_size
  end

  test "moving onto an occupied slot is rejected" do
    Reservation.create!(dining_table: dining_tables(:zurich_2), starts_at: @zurich_reservation.starts_at,
                        party_size: 2, guest_name: "Carl Gast", guest_email: "carl@example.com")
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation),
          params: edit_params(@zurich_reservation, dining_table_id: dining_tables(:zurich_2).id)

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /bereits vergeben/
    assert_equal dining_tables(:zurich_1), @zurich_reservation.reload.dining_table
  end

  test "moving a reservation into the past is rejected" do
    sign_in_as users(:staff)

    patch staff_reservation_path(@zurich_reservation),
          params: edit_params(@zurich_reservation, starts_at: 1.day.ago.strftime("%Y-%m-%dT%H:%M"))

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Zukunft/
  end

  test "concurrent change: stale version is rejected with the current state" do
    sign_in_as users(:staff)
    params = edit_params(@zurich_reservation, party_size: 4)      # Formular mit Version 0 geöffnet
    Reservation.find(@zurich_reservation.id).update!(party_size: 3) # Kollege speichert zuerst

    patch staff_reservation_path(@zurich_reservation), params: params

    assert_response :conflict
    assert_select "[data-conflict]", /inzwischen geändert/
    assert_equal 3, @zurich_reservation.reload.party_size
    # frisches Formular mit aktuellem Stand und aktueller Version
    assert_select "input[name='reservation[party_size]'][value='3']"
    assert_select "input[name='reservation[lock_version]'][value='#{@zurich_reservation.lock_version}']"
  end

  test "after a conflict the reloaded form can be saved" do
    sign_in_as users(:staff)
    params = edit_params(@zurich_reservation, party_size: 4)
    Reservation.find(@zurich_reservation.id).update!(party_size: 3)
    patch staff_reservation_path(@zurich_reservation), params: params
    assert_response :conflict

    patch staff_reservation_path(@zurich_reservation),
          params: edit_params(@zurich_reservation.reload, party_size: 4)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    assert_equal 4, @zurich_reservation.reload.party_size
  end

  test "guest cancelled meanwhile: editing is no longer possible" do
    sign_in_as users(:staff)
    params = edit_params(@zurich_reservation, party_size: 3)
    Reservation.find(@zurich_reservation.id).cancel

    patch staff_reservation_path(@zurich_reservation), params: params

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    follow_redirect!
    assert_match "nicht mehr bearbeitet", response.body
    assert_equal 2, @zurich_reservation.reload.party_size
  end

  test "cancelled reservations cannot be opened for editing" do
    @zurich_reservation.cancel
    sign_in_as users(:staff)

    get edit_staff_reservation_path(@zurich_reservation)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
  end

  test "details page offers edit and cancel only for confirmed reservations" do
    sign_in_as users(:staff)

    get staff_reservation_path(@zurich_reservation)
    assert_select "a[href=?]", edit_staff_reservation_path(@zurich_reservation)
    assert_select "form[action=?]", staff_reservation_cancellation_path(@zurich_reservation)

    @zurich_reservation.cancel
    get staff_reservation_path(@zurich_reservation)
    assert_select "a[href=?]", edit_staff_reservation_path(@zurich_reservation), count: 0
    assert_select "form[action=?]", staff_reservation_cancellation_path(@zurich_reservation), count: 0
  end
end