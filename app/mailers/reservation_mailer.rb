class ReservationMailer < ApplicationMailer
  def confirmation(reservation)
    @reservation = reservation
    @lookup_url = new_reservation_lookup_url(confirmation_code: reservation.confirmation_code)
    Rails.logger.debug "Reservationsbestätigung an #{reservation.guest_email}: " \
                       "Code #{reservation.confirmation_code}, Abruf: #{@lookup_url}"

    mail to: reservation.guest_email, subject: "Deine Tavolino-Reservation ist bestätigt"
  end
end