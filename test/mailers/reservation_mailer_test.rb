require "test_helper"

class ReservationMailerTest < ActionMailer::TestCase
  test "confirmation" do
    reservation = reservations(:zurich_dinner)

    mail = ReservationMailer.confirmation(reservation)

    assert_equal "Deine Tavolino-Reservation ist bestätigt", mail.subject
    assert_equal [ "anna@example.com" ], mail.to
    assert_equal [ "from@example.com" ], mail.from

    body = mail.text_part.decoded
    assert_match reservation.confirmation_code, body
    assert_match "Tavolino Zürich", body
    assert_match "/reservation_lookup/new", body
  end

  test "confirmation has no cancellation link" do
    mail = ReservationMailer.confirmation(reservations(:zurich_dinner))

    assert_no_match "cancellation", mail.text_part.decoded
    assert_no_match "cancellation", mail.html_part.decoded
  end
end