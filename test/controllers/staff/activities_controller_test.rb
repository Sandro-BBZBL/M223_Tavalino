require "test_helper"

class Staff::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @zurich = reservations(:zurich_dinner)   # Zürich
    @luzern = reservations(:luzern_lunch)    # Luzern

    # Fixtures erzeugen keine Versionen: erst Änderungen auslösen (Luzern zuletzt)
    PaperTrail.request(whodunnit: users(:staff).id.to_s) { @zurich.update!(party_size: 3) }
    PaperTrail.request(whodunnit: users(:staff_luzern).id.to_s) { @luzern.update!(party_size: 3) }
  end

  def row_for(reservation)
    "tr[data-reservation-id='#{reservation.id}']"
  end

  test "visitors are redirected to the login" do
    get staff_activities_path

    assert_redirected_to new_user_session_path
  end

  test "staff sees activities of their own location with actor and changes" do
    sign_in_as users(:staff)

    get staff_activities_path

    assert_response :success
    assert_select row_for(@zurich) do
      assert_select "td", text: users(:staff).name
      assert_select "td", text: "geändert"
      assert_select "li", text: "Personenzahl: 2 → 3"
    end
  end

  test "staff does not see activities of foreign locations" do
    sign_in_as users(:staff)

    get staff_activities_path

    assert_select row_for(@luzern), count: 0
  end

  test "staff of another location sees only their own activities" do
    sign_in_as users(:staff_luzern)

    get staff_activities_path

    assert_select row_for(@luzern)
    assert_select row_for(@zurich), count: 0
  end

  test "admin sees the activities of all locations, newest first" do
    sign_in_as users(:admin)

    get staff_activities_path

    assert_select row_for(@zurich)
    assert_select row_for(@luzern)
    reservation_ids = css_select("tr[data-reservation-id]").map { |row| row["data-reservation-id"].to_i }
    assert_equal [ @luzern.id, @zurich.id ], reservation_ids
  end

  test "staff without a location sees an empty feed" do
    sign_in_as users(:staff_unassigned)

    get staff_activities_path

    assert_response :success
    assert_select "tr[data-version-id]", count: 0
    assert_match "Noch keine Aktivitäten", response.body
  end

  test "a guest booking shows up as booked by Gast and never exposes the code" do
    post reservations_path, params: { reservation: {
      dining_table_id: dining_tables(:zurich_2).id,
      starts_at: (@zurich.starts_at + 1.day).iso8601,
      party_size: 2,
      guest_name: "Bob Gast",
      guest_email: "bob@example.com",
      guest_phone: ""
    } }
    booked = Reservation.find_by!(guest_email: "bob@example.com")

    sign_in_as users(:staff)
    get staff_activities_path

    assert_select row_for(booked) do
      assert_select "td", text: "Gast"
      assert_select "td", text: "gebucht"
    end
    assert_no_match booked.confirmation_code, response.body
  end

  test "the feed shows at most the newest 100 entries" do
    101.times { |i| @zurich.update!(party_size: i.even? ? 2 : 3) }
    sign_in_as users(:admin)

    get staff_activities_path

    assert_select "tr[data-version-id]", count: Staff::ActivitiesController::LIMIT
  end

  test "the navigation links to the feed" do
    sign_in_as users(:staff)

    get staff_reservations_path

    assert_select "a[href=?]", staff_activities_path
  end
end