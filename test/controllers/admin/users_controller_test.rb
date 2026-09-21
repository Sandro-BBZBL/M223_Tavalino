require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin User", email_address: "admin@example.com", password: "password12345", password_confirmation: "password12345", role: :admin)
    @staff = User.create!(name: "Staff User", email_address: "staff@example.com", password: "password12345", password_confirmation: "password12345", role: :staff)
  end

  test "admin can access the user overview" do
    post user_sessions_path, params: { user: { email_address: @admin.email_address, password: "password12345" } }

    get admin_users_path

    assert_response :success
    assert_select "table"
    assert_select "td", /#{Regexp.escape(@staff.name)}/
  end

  test "staff cannot access the user overview" do
    post user_sessions_path, params: { user: { email_address: @staff.email_address, password: "password12345" } }

    get admin_users_path

    assert_redirected_to root_path
    follow_redirect!
    assert_match "keine Berechtigung", response.body
  end

  test "admin can update a user's role" do
    post user_sessions_path, params: { user: { email_address: @admin.email_address, password: "password12345" } }

    patch admin_user_path(@staff), params: { user: { name: @staff.name, email_address: @staff.email_address, role: "admin" } }

    assert_redirected_to admin_users_path
    assert @staff.reload.admin?
  end

  test "admin can assign locations to a user" do
    post user_sessions_path, params: { user: { email_address: @admin.email_address, password: "password12345" } }
    zurich = locations(:zurich)

    patch admin_user_path(@staff), params: { user: { name: @staff.name, email_address: @staff.email_address, role: "staff", location_ids: [ "", zurich.id.to_s ] } }

    assert_redirected_to admin_users_path
    assert_equal [ zurich ], @staff.reload.locations.to_a
  end

  test "admin cannot remove their own admin role" do
    post user_sessions_path, params: { user: { email_address: @admin.email_address, password: "password12345" } }

    patch admin_user_path(@admin), params: { user: { name: @admin.name, email_address: @admin.email_address, role: "staff" } }

    assert_response :unprocessable_entity
    assert @admin.reload.admin?
  end
end