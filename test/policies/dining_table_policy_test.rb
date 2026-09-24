require "test_helper"

class DiningTablePolicyTest < ActiveSupport::TestCase
  def visible_to(user)
    DiningTablePolicy::Scope.new(user, DiningTable).resolve.to_a
  end

  test "admin sees all tables" do
    assert_equal DiningTable.count, visible_to(users(:admin)).size
  end

  test "staff sees only tables of their locations" do
    tables = visible_to(users(:staff))

    assert_includes tables, dining_tables(:zurich_1)
    assert_not_includes tables, dining_tables(:luzern_1)
  end

  test "staff without a location sees no tables" do
    assert_empty visible_to(users(:staff_unassigned))
  end

  test "visitors see no tables" do
    assert_empty visible_to(nil)
  end
end