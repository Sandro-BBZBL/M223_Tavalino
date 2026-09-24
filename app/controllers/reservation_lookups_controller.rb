# Gast ruft seine Reservation mit Reservationscode + E-Mail-Adresse ab
# (funktioniert in jeder Session, auch Tage nach der Buchung).
class ReservationLookupsController < ApplicationController
  # Schutz gegen Durchprobieren von Codes (nutzt den Rails-Cache)
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_reservation_lookup_path, alert: "Zu viele Versuche. Bitte warte kurz." }

  def new
    @confirmation_code = params[:confirmation_code]
  end

  def create
    @confirmation_code = lookup_params[:confirmation_code]
    reservation = Reservation.find_for_guest(@confirmation_code, lookup_params[:email])

    if reservation
      remember_reservation(reservation)
      redirect_to reservation_path(reservation)
    else
      # Bewusst immer dieselbe Meldung: kein Hinweis, ob Code oder E-Mail falsch war
      flash.now[:alert] = "Keine Reservation gefunden. Bitte prüfe Code und E-Mail-Adresse."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def lookup_params
    params.fetch(:lookup, {}).permit(:confirmation_code, :email)
  end
end