# Gast storniert seine Reservation (nur bis 2 Stunden vor dem Termin)
class CancellationsController < ApplicationController
  def create
    reservation = Reservation.find_by(id: params[:reservation_id])

    unless reservation && reservation_known?(reservation)
      return redirect_to new_reservation_lookup_path, alert: "Bitte gib Reservationscode und E-Mail-Adresse ein."
    end

    if reservation.cancel
      redirect_to reservation_path(reservation), notice: "Deine Reservation wurde storniert."
    else
      redirect_to reservation_path(reservation), alert: reservation.errors.full_messages.to_sentence
    end
  end
end