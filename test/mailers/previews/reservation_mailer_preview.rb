# Vorschau unter http://localhost:3000/rails/mailers/reservation_mailer/confirmation
class ReservationMailerPreview < ActionMailer::Preview
  def confirmation
    reservation = Reservation.first || Reservation.new(
      dining_table: DiningTable.first, # benötigt Seed-Daten (bin/rails db:seed)
      starts_at: 2.days.from_now.change(hour: 19),
      party_size: 2,
      guest_name: "Vorschau Gast",
      guest_email: "vorschau@example.com",
      confirmation_code: "vorschaucode000000000001"
    )
    ReservationMailer.confirmation(reservation)
  end
end