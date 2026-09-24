require "test_helper"

# Prüft end-to-end, dass Änderungen protokolliert werden und wer der Akteur ist:
# Gäste (kein Konto) = whodunnit leer, Mitarbeiter/Admins = ihre Benutzer-ID.
class ActivityLogTest < ActionDispatch::IntegrationTest
  setup do
    # zurich_dinner: Tisch zurich_1 (4 Plätze), in 3 Tagen 19:00-21:00
    @dinner = reservations(:zurich_dinner)
    @next_day = (@dinner.starts_at + 1.day).strftime("%Y-%m-%dT%H:%M")
  end

  def booking_params(email: "bob@example.com", overrides: {})
    { reservation: {
      dining_table_id: dining_tables(:zurich_2).id,
      starts_at: @next_day,
      party_size: 2,
      guest_name: "Bob Gast",
      guest_email: email,
      guest_phone: ""
    }.merge(overrides) }
  end

  def edit_params(reservation, overrides = {})
    { reservation: {
      dining_table_id: reservation.dining_table_id,
      starts_at: reservation.starts_at.strftime("%Y-%m-%dT%H:%M"),
      party_size: reservation.party_size,
      guest_name: reservation.guest_name,
      guest_email: reservation.guest_email,
      guest_phone: reservation.guest_phone.to_s,
      lock_version: reservation.lock_version
    }.merge(overrides) }
  end

  def last_version(reservation)
    reservation.versions.reorder(:id).last
  end

  # --- Gäste ------------------------------------------------------------------

  test "guest booking is logged with the guest as actor" do
    post reservations_path, params: booking_params

    version = last_version(Reservation.find_by!(guest_email: "bob@example.com"))
    assert_equal "create", version.event
    assert_nil version.whodunnit
  end

  test "guest cancellation is logged with the guest as actor" do
    post reservation_lookup_path,
         params: { lookup: { confirmation_code: @dinner.confirmation_code, email: "anna@example.com" } }

    assert_difference "@dinner.versions.count", 1 do
      post reservation_cancellation_path(@dinner)
    end

    version = last_version(@dinner)
    assert_nil version.whodunnit
    assert_equal [ "confirmed", "cancelled" ], version.changeset["status"]
  end

  test "a staff member browsing as guest is still logged as guest" do
    sign_in_as users(:staff)

    post reservations_path, params: booking_params

    assert_nil last_version(Reservation.find_by!(guest_email: "bob@example.com")).whodunnit
  end

  test "a rejected guest booking is not logged" do
    post reservations_path, params: booking_params

    assert_no_difference "PaperTrail::Version.count" do
      post reservations_path, params: booking_params(email: "carl@example.com")
    end
  end

  # --- Mitarbeiter und Admins -------------------------------------------------

  test "manually recorded reservation is logged with the staff member" do
    sign_in_as users(:staff)

    post staff_reservations_path, params: booking_params(email: "peter@example.com")

    version = last_version(Reservation.find_by!(guest_email: "peter@example.com"))
    assert_equal "create", version.event
    assert_equal users(:staff).id.to_s, version.whodunnit
  end

  test "staff edit is logged with the changed fields and the staff member" do
    sign_in_as users(:staff)

    assert_difference "@dinner.versions.count", 1 do
      patch staff_reservation_path(@dinner), params: edit_params(@dinner, party_size: 3)
    end

    version = last_version(@dinner)
    assert_equal users(:staff).id.to_s, version.whodunnit
    assert_equal [ 2, 3 ], version.changeset["party_size"]
  end

  test "staff cancellation is logged with the staff member" do
    sign_in_as users(:staff)

    post staff_reservation_cancellation_path(@dinner)

    version = last_version(@dinner)
    assert_equal users(:staff).id.to_s, version.whodunnit
    assert_equal [ "confirmed", "cancelled" ], version.changeset["status"]
  end

  test "admin actions are logged with the admin" do
    sign_in_as users(:admin)

    patch staff_reservation_path(reservations(:luzern_lunch)),
          params: edit_params(reservations(:luzern_lunch), guest_name: "Lena Neu")

    version = last_version(reservations(:luzern_lunch))
    assert_equal users(:admin).id.to_s, version.whodunnit
    assert_equal [ "Lena Luzern", "Lena Neu" ], version.changeset["guest_name"]
  end

  test "an edit rejected by a version conflict is not logged" do
    sign_in_as users(:staff)
    params = edit_params(@dinner, party_size: 4)
    Reservation.find(@dinner.id).update!(party_size: 3) # Kollege war schneller

    assert_no_difference "PaperTrail::Version.count" do
      patch staff_reservation_path(@dinner), params: params
    end
    assert_response :conflict
  end

  test "an edit rejected by validation is not logged" do
    sign_in_as users(:staff)

    assert_no_difference "PaperTrail::Version.count" do
      patch staff_reservation_path(@dinner), params: edit_params(@dinner, party_size: 9)
    end
    assert_response :unprocessable_entity
  end

  test "a denied foreign edit is not logged" do
    sign_in_as users(:staff)

    assert_no_difference "PaperTrail::Version.count" do
      patch staff_reservation_path(reservations(:luzern_lunch)),
            params: edit_params(reservations(:luzern_lunch), guest_name: "Gehackt")
    end
  end
end