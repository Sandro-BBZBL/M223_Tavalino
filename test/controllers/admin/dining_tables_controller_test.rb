require "test_helper"

class Admin::DiningTablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @zurich = locations(:zurich)
    @luzern = locations(:luzern)
    @table = dining_tables(:zurich_1) # hat die zurich_dinner-Fixture als künftige Reservation
  end

  # --- Zugriffsschutz -----------------------------------------------------------

  test "visitors are redirected to the login" do
    get admin_location_dining_tables_path(@zurich)
    assert_redirected_to new_user_session_path
  end

  test "staff has no access, even to their own location" do
    sign_in_as users(:staff)

    get admin_location_dining_tables_path(@zurich)
    assert_redirected_to root_path
    follow_redirect!
    assert_match "keine Berechtigung", response.body

    get new_admin_location_dining_table_path(@zurich)
    assert_redirected_to root_path

    get edit_admin_location_dining_table_path(@zurich, @table)
    assert_redirected_to root_path
  end

  test "a table from a foreign location returns 404" do
    sign_in_as users(:admin)

    get edit_admin_location_dining_table_path(@luzern, @table) # @table gehört zu Zürich

    assert_response :not_found
  end

  # --- Liste ----------------------------------------------------------------

  test "admin sees the tables of the location with the upcoming reservation count" do
    table = dining_tables(:zurich_2) # noch ohne künftige Reservation
    Reservation.create!(dining_table: table, starts_at: 2.days.from_now, party_size: 2,
                        guest_name: "Gast", guest_email: "gast@example.com")
    sign_in_as users(:admin)

    get admin_location_dining_tables_path(@zurich)

    assert_response :success
    assert_select "tr[data-table-id='#{table.id}']" do
      assert_select "td[data-upcoming]", "1"
    end
    assert_select "tr[data-table-id='#{dining_tables(:luzern_1).id}']", count: 0
  end

  # --- Anlegen ----------------------------------------------------------------

  test "admin creates a new table" do
    sign_in_as users(:admin)

    assert_difference "@zurich.dining_tables.count", 1 do
      post admin_location_dining_tables_path(@zurich), params: { dining_table: { number: 9, capacity: 4, active: "1" } }
    end

    assert_redirected_to admin_location_dining_tables_path(@zurich)
  end

  test "creating a table with a duplicate number at the same location is rejected" do
    sign_in_as users(:admin)

    assert_no_difference "DiningTable.count" do
      post admin_location_dining_tables_path(@zurich),
           params: { dining_table: { number: @table.number, capacity: 4, active: "1" } }
    end

    assert_response :unprocessable_entity
  end

  test "the same number is allowed at a different location" do
    sign_in_as users(:admin)

    # Nummer 42 ist an keinem der beiden Standorte vergeben
    assert_difference "DiningTable.count", 1 do
      post admin_location_dining_tables_path(@luzern),
           params: { dining_table: { number: 42, capacity: 4, active: "1" } }
    end
  end

  # --- Bearbeiten ---------------------------------------------------------------

  test "admin reduces capacity when it still fits upcoming reservations" do
    sign_in_as users(:admin)

    patch admin_location_dining_table_path(@zurich, @table), params: { dining_table: { capacity: 3 } }

    assert_redirected_to admin_location_dining_tables_path(@zurich)
    assert_equal 3, @table.reload.capacity
  end

  test "reducing capacity below an upcoming reservation's party size is rejected" do
    table = dining_tables(:zurich_2)
    Reservation.create!(dining_table: table, starts_at: 2.days.from_now, party_size: 2,
                        guest_name: "Gast", guest_email: "gast@example.com")
    sign_in_as users(:admin)

    patch admin_location_dining_table_path(@zurich, table), params: { dining_table: { capacity: 1 } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Kapazität ist zu klein/
    assert_equal 2, table.reload.capacity
  end

  test "deactivating a table with upcoming reservations is rejected" do
    sign_in_as users(:admin)

    patch admin_location_dining_table_path(@zurich, @table), params: { dining_table: { active: "0" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /kann nicht deaktiviert werden/
    assert @table.reload.active?
  end

  test "a table without upcoming reservations can be deactivated" do
    table = dining_tables(:zurich_2)
    sign_in_as users(:admin)

    patch admin_location_dining_table_path(@zurich, table), params: { dining_table: { active: "0" } }

    assert_redirected_to admin_location_dining_tables_path(@zurich)
    assert_not table.reload.active?
  end

  test "a deactivated table disappears from the guest search" do
    table = dining_tables(:zurich_2)
    sign_in_as users(:admin)
    patch admin_location_dining_table_path(@zurich, table), params: { dining_table: { active: "0" } }

    tables = DiningTable.available_for(location: @zurich, starts_at: 2.days.from_now.change(hour: 19), party_size: 2)
    assert_not_includes tables, table
  end
end