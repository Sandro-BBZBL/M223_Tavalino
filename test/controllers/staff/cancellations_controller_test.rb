require "test_helper"

class Staff::CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @zurich_reservation = reservations(:zurich_dinner)
    @luzern_reservation = reservations(:luzern_lunch)
  end

  test "visitors cannot cancel" do
    post staff_reservation_cancellation_path(@zurich_reservation)

    assert_redirected_to new_user_session_path
    assert @zurich_reservation.reload.confirmed?
  end

  test "staff cancels a reservation of their location" do
    sign_in_as users(:staff)

    post staff_reservation_cancellation_path(@zurich_reservation)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    assert @zurich_reservation.reload.cancelled?
    follow_redirect!
    assert_match "storniert", response.body
  end

  test "staff can cancel even less than 2 hours before the start" do
    sign_in_as users(:staff)

    travel_to(@zurich_reservation.starts_at - 30.minutes) do
      post staff_reservation_cancellation_path(@zurich_reservation)
    end

    assert @zurich_reservation.reload.cancelled?
  end

  test "cancelled reservation frees the table again" do
    sign_in_as users(:staff)

    post staff_reservation_cancellation_path(@zurich_reservation)

    tables = DiningTable.available_for(location: locations(:zurich),
                                       starts_at: @zurich_reservation.starts_at, party_size: 2)
    assert_includes tables, dining_tables(:zurich_1)
  end

  test "staff cannot cancel a reservation of a foreign location" do
    sign_in_as users(:staff)

    post staff_reservation_cancellation_path(@luzern_reservation)

    assert_redirected_to root_path
    assert @luzern_reservation.reload.confirmed?
  end

  test "staff without a location cannot cancel" do
    sign_in_as users(:staff_unassigned)

    post staff_reservation_cancellation_path(@zurich_reservation)

    assert_redirected_to root_path
    assert @zurich_reservation.reload.confirmed?
  end

  test "admin can cancel reservations of any location" do
    sign_in_as users(:admin)

    post staff_reservation_cancellation_path(@luzern_reservation)

    assert @luzern_reservation.reload.cancelled?
  end

  test "cancelling twice shows a message and changes nothing" do
    sign_in_as users(:staff)
    post staff_reservation_cancellation_path(@zurich_reservation)

    post staff_reservation_cancellation_path(@zurich_reservation)

    assert_redirected_to staff_reservation_path(@zurich_reservation)
    follow_redirect!
    assert_match "bereits storniert", response.body
  end
end