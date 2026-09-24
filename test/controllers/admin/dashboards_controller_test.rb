require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "visitors are redirected to the login" do
    get admin_dashboard_path

    assert_redirected_to new_user_session_path
  end

  test "staff has no access to the dashboard" do
    sign_in_as users(:staff)

    get admin_dashboard_path

    assert_redirected_to root_path
    follow_redirect!
    assert_match "keine Berechtigung", response.body
  end

  test "admin can open the dashboard" do
    sign_in_as users(:admin)

    get admin_dashboard_path

    assert_response :success
    assert_select "h1", "Dashboard"
  end
end