require "test_helper"

class ReservationLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # zurich_dinner: Code fixturecode000000000001, Gast anna@example.com
    @dinner = reservations(:zurich_dinner)
  end

  def lookup(code: @dinner.confirmation_code, email: "anna@example.com")
    post reservation_lookup_path, params: { lookup: { confirmation_code: code, email: email } }
  end

  test "shows the lookup form without login" do
    get new_reservation_lookup_path

    assert_response :success
    assert_select "form input[name='lookup[confirmation_code]']"
    assert_select "form input[name='lookup[email]']"
  end

  test "code from the mail link is prefilled" do
    get new_reservation_lookup_path(confirmation_code: "abc123")

    assert_select "input[name='lookup[confirmation_code]'][value='abc123']"
  end

  test "guest finds the reservation with code and email in a fresh session" do
    lookup

    assert_redirected_to reservation_path(@dinner)
    follow_redirect!
    assert_response :success
    assert_match "Anna Gast", response.body
    assert_match @dinner.confirmation_code, response.body
  end

  test "email is matched case-insensitively and trimmed" do
    lookup(email: "  ANNA@Example.com ")

    assert_redirected_to reservation_path(@dinner)
  end

  test "wrong email shows a generic error" do
    lookup(email: "andere@example.com")

    assert_response :unprocessable_entity
    assert_match "Keine Reservation gefunden", response.body
  end

  test "wrong code shows the same generic error" do
    lookup(code: "falscher-code")

    assert_response :unprocessable_entity
    assert_match "Keine Reservation gefunden", response.body
  end

  test "blank input is rejected" do
    lookup(code: "", email: "")

    assert_response :unprocessable_entity
  end

  test "failed lookup does not unlock the reservation" do
    lookup(email: "andere@example.com")

    get reservation_path(@dinner)
    assert_redirected_to new_reservation_lookup_path
  end

  test "details page does not show the phone number" do
    @dinner.update!(guest_phone: "079 123 45 67")
    lookup

    follow_redirect!
    assert_no_match "079 123 45 67", response.body
  end
end