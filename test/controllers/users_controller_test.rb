require "test_helper"

class UserSessionsControllerTest < ActionDispatch::IntegrationTest
  test "staff lands on the reservation overview after login" do
    sign_in_as users(:staff)

    assert_redirected_to staff_reservations_path
  end

  test "admin lands on the reservation overview after login" do
    sign_in_as users(:admin)

    assert_redirected_to staff_reservations_path
  end

  test "wrong password is rejected with a generic message" do
    sign_in_as users(:staff), password: "falsches-passwort"

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match "E-Mail oder Passwort ist falsch", response.body
  end

  test "unknown email gets the same message" do
    post user_sessions_path, params: { user: { email_address: "niemand@example.com", password: "password12345" } }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match "E-Mail oder Passwort ist falsch", response.body
  end

  test "logout ends the session" do
    sign_in_as users(:staff)

    delete user_session_path(users(:staff))
    get staff_reservations_path

    assert_redirected_to new_user_session_path
  end
end