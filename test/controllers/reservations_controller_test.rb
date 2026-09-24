require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
    @table = dining_tables(:zurich_2)
    @starts_at = (@dinner.starts_at + 1.day).iso8601
  end

  def booking_params(overrides = {})
    { reservation: {
      dining_table_id: @table.id,
      starts_at: @starts_at,
      party_size: 2,
      guest_name: "Bob Gast",
      guest_email: "bob@example.com",
      guest_phone: "079 000 00 00"
    }.merge(overrides) }
  end

  test "guest sees the booking form" do
    get new_reservation_path(dining_table_id: @table.id, starts_at: @starts_at, party_size: 2)

    assert_response :success
    assert_select "form input[name='reservation[guest_name]']"
    assert_select "form input[name='reservation[guest_email]']"
  end

  test "guest books a free table and sees the confirmation with code" do
    assert_difference "Reservation.count", 1 do
      post reservations_path, params: booking_params
    end

    reservation = Reservation.find_by!(guest_email: "bob@example.com")
    assert_redirected_to reservation_path(reservation)
    assert reservation.confirmed?
    assert_nil reservation.user_id

    follow_redirect!
    assert_response :success
    assert_match reservation.confirmation_code, response.body
  end

  test "booking sends a confirmation mail with code and lookup link" do
    assert_enqueued_emails 1 do
      post reservations_path, params: booking_params
    end

    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    reservation = Reservation.find_by!(guest_email: "bob@example.com")
    assert_equal [ "bob@example.com" ], mail.to
    assert_match reservation.confirmation_code, mail.text_part.decoded
    assert_match "/reservation_lookup/new", mail.text_part.decoded
  end

  test "failed booking sends no mail" do
    assert_no_enqueued_emails do
      post reservations_path, params: booking_params(guest_name: "")
    end
  end

  test "booking the same slot twice is rejected with alternatives" do
    post reservations_path, params: booking_params

    assert_no_difference "Reservation.count" do
      post reservations_path, params: booking_params(guest_email: "carl@example.com")
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /bereits vergeben/
    assert_select "[data-alternatives]"
  end

  test "overlapping slot on a booked table is rejected" do
    assert_no_difference "Reservation.count" do
      post reservations_path,
           params: booking_params(dining_table_id: dining_tables(:zurich_1).id,
                                  starts_at: (@dinner.starts_at + 1.hour).iso8601)
    end

    assert_response :unprocessable_entity
    assert_select "[data-alternatives]"
  end

  test "invalid guest data is rejected" do
    assert_no_difference "Reservation.count" do
      post reservations_path, params: booking_params(guest_email: "kaputt", guest_name: "")
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]"
  end

  test "inactive table cannot be booked" do
    assert_no_difference "Reservation.count" do
      post reservations_path, params: booking_params(dining_table_id: dining_tables(:zurich_inactive).id)
    end

    assert_response :unprocessable_entity
  end

  test "too many guests for the table are rejected" do
    assert_no_difference "Reservation.count" do
      post reservations_path, params: booking_params(party_size: 3)
    end

    assert_response :unprocessable_entity
  end

  test "details page redirects to the lookup form for foreign reservations" do
    get reservation_path(@dinner)

    assert_redirected_to new_reservation_lookup_path
  end
end