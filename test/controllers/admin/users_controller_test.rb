require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin can access the user overview" do
    sign_in_as users(:admin)

    get admin_users_path

    assert_response :success
    assert_select "table"
    assert_select "td", /#{Regexp.escape(users(:staff).name)}/
  end

  test "staff cannot access the user overview" do
    sign_in_as users(:staff)

    get admin_users_path

    assert_redirected_to root_path
    follow_redirect!
    assert_match "keine Berechtigung", response.body
  end

  test "admin can update a user's role" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:staff)),
          params: { user: { name: users(:staff).name, email_address: users(:staff).email_address, role: "admin" } }

    assert_redirected_to admin_users_path
    assert users(:staff).reload.admin?
  end

  test "admin can assign locations to a user" do
    sign_in_as users(:admin)
    zurich = locations(:zurich)

    patch admin_user_path(users(:staff_unassigned)),
          params: { user: { name: users(:staff_unassigned).name, email_address: users(:staff_unassigned).email_address,
                            role: "staff", location_ids: [ "", zurich.id.to_s ] } }

    assert_redirected_to admin_users_path
    assert_equal [ zurich ], users(:staff_unassigned).reload.locations.to_a
  end

  test "admin cannot remove their own admin role" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:admin)),
          params: { user: { name: users(:admin).name, email_address: users(:admin).email_address, role: "staff" } }

    assert_response :unprocessable_entity
    assert users(:admin).reload.admin?
  end
end