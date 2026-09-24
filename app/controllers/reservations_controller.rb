# Öffentlicher Gast-Flow: Reservation abschliessen und Details anzeigen
class ReservationsController < ApplicationController
  before_action :set_dining_table, only: %i[new create]

  def new
    @reservation = Reservation.new(
      dining_table: @dining_table,
      starts_at: params[:starts_at],
      party_size: params[:party_size]
    )
  end

  def create
    @reservation = Reservation.new(reservation_params)

    if @reservation.book
      remember_reservation(@reservation)
      # deliver_later: Eine Mail-Panne darf die bereits gespeicherte Buchung nicht scheitern lassen
      ReservationMailer.confirmation(@reservation).deliver_later
      redirect_to reservation_path(@reservation), notice: "Deine Reservation ist bestätigt."
    else
      @alternatives = alternatives if @reservation.slot_taken?
      render :new, status: :unprocessable_entity
    end
  end

  # Details: nur nach Buchung oder Abruf mit Code + E-Mail (siehe ReservationLookupsController)
  def show
    @reservation = Reservation.find_by(id: params[:id])

    unless @reservation && reservation_known?(@reservation)
      redirect_to new_reservation_lookup_path, alert: "Bitte gib Reservationscode und E-Mail-Adresse ein."
    end
  end

  private

  def set_dining_table
    @dining_table = DiningTable.find(params[:dining_table_id] || params.dig(:reservation, :dining_table_id))
  end

  def reservation_params
    params.expect(reservation: %i[dining_table_id starts_at party_size guest_name guest_email guest_phone])
  end

  def alternatives
    return unless @reservation.starts_at && @reservation.party_size

    ReservationSearch.alternatives_for(location: @dining_table.location,
                                       starts_at: @reservation.starts_at,
                                       party_size: @reservation.party_size)
  end
end