# Mitarbeiter/Admins stornieren eine Reservation (ohne 2-Stunden-Frist der Gäste).
# Hinweis: Die Stornierung arbeitet immer mit dem aktuellen Stand aus der Datenbank.
# Ist die Reservation schon storniert, meldet das Model "bereits storniert".
class Staff::CancellationsController < Staff::BaseController
  def create
    reservation = Reservation.find(params[:reservation_id])
    authorize reservation, :cancel?

    if reservation.cancel(respecting_deadline: false)
      redirect_to staff_reservation_path(reservation), notice: "Die Reservation wurde storniert."
    else
      redirect_to staff_reservation_path(reservation), alert: reservation.errors.full_messages.to_sentence
    end
  end
end