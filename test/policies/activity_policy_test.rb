require "test_helper"

class ActivityPolicyTest < ActiveSupport::TestCase
  setup do
    @zurich = reservations(:zurich_dinner)
    @luzern = reservations(:luzern_lunch)

    # Fixtures erzeugen keine Versionen: erst Änderungen auslösen
    @zurich.update!(party_size: 3)
    @luzern.update!(party_size: 3)
    @zurich_version = @zurich.versions.last
    @luzern_version = @luzern.versions.last

    @admin = users(:admin)
    @staff_zurich = users(:staff)
    @staff_luzern = users(:staff_luzern)
    @staff_unassigned = users(:staff_unassigned)
  end

  def visible_to(user)
    ActivityPolicy::Scope.new(user, PaperTrail::Version).resolve.to_a
  end

  # --- index? -----------------------------------------------------------------

  test "every signed in user may open the feed" do
    assert ActivityPolicy.new(@admin, :activity).index?
    assert ActivityPolicy.new(@staff_zurich, :activity).index?
    assert ActivityPolicy.new(@staff_unassigned, :activity).index?
  end

  test "visitors may not open the feed" do
    assert_not ActivityPolicy.new(nil, :activity).index?
  end

  # --- Scope ------------------------------------------------------------------

  test "admin sees the activities of all locations" do
    versions = visible_to(@admin)

    assert_includes versions, @zurich_version
    assert_includes versions, @luzern_version
  end

  test "staff sees only activities of reservations of their locations" do
    assert_equal [ @zurich_version ], visible_to(@staff_zurich)
    assert_equal [ @luzern_version ], visible_to(@staff_luzern)
  end

  test "staff without a location sees no activities" do
    assert_empty visible_to(@staff_unassigned)
  end

  test "visitors see no activities" do
    assert_empty visible_to(nil)
  end

  test "only versions of reservations are part of the feed" do
    foreign = PaperTrail::Version.create!(item_type: "User", item_id: @admin.id, event: "update")

    assert_not_includes visible_to(@admin), foreign
  end
end