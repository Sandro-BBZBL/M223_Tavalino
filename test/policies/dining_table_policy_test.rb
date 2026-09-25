require "test_helper"

class DiningTablePolicyTest < ActiveSupport::TestCase
  def policy(user)
    DiningTablePolicy.new(user, dining_tables(:zurich_1))
  end

  def visible_to(user)
    DiningTablePolicy::Scope.new(user, DiningTable).resolve.to_a
  end

  # --- index? / create? / update? (nur Admin) ----------------------------------

  test "admin may manage tables" do
    assert policy(users(:admin)).index?
    assert policy(users(:admin)).create?
    assert policy(users(:admin)).new?
    assert policy(users(:admin)).update?
    assert policy(users(:admin)).edit?
  end

  test "staff may not manage tables, even of their own location" do
    assert_not policy(users(:staff)).index?
    assert_not policy(users(:staff)).create?
    assert_not policy(users(:staff)).update?
  end

  test "visitors may not manage tables" do
    assert_not policy(nil).index?
    assert_not policy(nil).create?
    assert_not policy(nil).update?
  end

  # --- Scope (Tischauswahl beim Erfassen/Bearbeiten) ---------------------------

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