require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "start page is public and lists all locations" do
    get root_path

    assert_response :success
    assert_select "a", text: locations(:zurich).name
    assert_select "a", text: locations(:luzern).name
  end
end