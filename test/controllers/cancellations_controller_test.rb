require "test_helper"

class CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # zurich_dinner: in 3 Tagen, also weit vor der 2-Stunden-Frist
    @dinner = reservations(:zurich_dinner)
  end

  def guest_signs_in(reservation, email: "anna@example.com")
    post reservation_lookup_path,
         params: { lookup: { confirmation_code: reservation.confirmation_code, email: email } }
  end

  test "details page offers cancellation before the deadline" do
    guest_signs_in(@dinner)

    get reservation_path(@dinner)
    assert_select "form[action='#{reservation_cancellation_path(@dinner)}']"
  end

  test "guest cancels before the deadline" do
    guest_signs_in(@dinner)

    post reservation_cancellation_path(@dinner)

    assert_redirected_to reservation_path(@dinner)
    assert @dinner.reload.cancelled?
    follow_redirect!
    assert_match "storniert", response.body
    assert_select "form[action='#{reservation_cancellation_path(@dinner)}']", count: 0
  end

  test "guest cannot cancel less than 2 hours before the start" do
    travel_to(@dinner.starts_at - 1.hour) do
      guest_signs_in(@dinner)

      get reservation_path(@dinner)
      assert_select "form[action='#{reservation_cancellation_path(@dinner)}']", count: 0

      post reservation_cancellation_path(@dinner)
      assert_redirected_to reservation_path(@dinner)
      follow_redirect!
      assert_match "2 Stunden", response.body
    end

    assert @dinner.reload.confirmed?
  end

  test "cannot cancel without looking the reservation up first" do
    post reservation_cancellation_path(@dinner)

    assert_redirected_to new_reservation_lookup_path
    assert @dinner.reload.confirmed?
  end

  test "cannot cancel a foreign reservation" do
    other = Reservation.create!(dining_table: dining_tables(:zurich_2),
                                starts_at: @dinner.starts_at + 1.day, party_size: 2,
                                guest_name: "Carl Gast", guest_email: "carl@example.com")
    guest_signs_in(@dinner)

    post reservation_cancellation_path(other)

    assert_redirected_to new_reservation_lookup_path
    assert other.reload.confirmed?
  end

  test "cancelling twice shows a message and changes nothing" do
    guest_signs_in(@dinner)
    post reservation_cancellation_path(@dinner)

    post reservation_cancellation_path(@dinner)

    assert_redirected_to reservation_path(@dinner)
    follow_redirect!
    assert_match "bereits storniert", response.body
  end
end