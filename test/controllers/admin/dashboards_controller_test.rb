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

  test "admin sees all locations with active and inactive table counts" do
    sign_in_as users(:admin)

    get admin_dashboard_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "tr[data-location-id='#{locations(:zurich).id}']" do
      assert_select "td[data-active-count]", "2"
      assert_select "td[data-inactive-count]", "1"
      assert_select "td[data-seats]", "6" # zurich_1 (4) + zurich_2 (2)
    end
    assert_select "a[href=?]", admin_location_dining_tables_path(locations(:zurich))
  end

  test "dashboard links to users and activities" do
    sign_in_as users(:admin)

    get admin_dashboard_path

    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", staff_activities_path
  end
end