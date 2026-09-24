require "test_helper"

class LocationPolicyTest < ActiveSupport::TestCase
  def visible_to(user)
    LocationPolicy::Scope.new(user, Location).resolve.to_a
  end

  test "admin sees all locations" do
    assert_equal Location.count, visible_to(users(:admin)).size
  end

  test "staff sees only assigned locations" do
    assert_equal [ locations(:zurich) ], visible_to(users(:staff))
    assert_equal [ locations(:luzern) ], visible_to(users(:staff_luzern))
  end

  test "staff without a location sees none" do
    assert_empty visible_to(users(:staff_unassigned))
  end

  test "visitors see none" do
    assert_empty visible_to(nil)
  end
end