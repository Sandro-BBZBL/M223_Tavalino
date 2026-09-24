class Staff::ReservationsController < Staff::BaseController
  before_action :set_reservation, only: %i[show edit update]
  before_action :ensure_confirmed, only: %i[edit update]
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Reservation
    @locations = policy_scope(Location).order(:name)
    @reservations = filtered(policy_scope(Reservation)).order(:starts_at).to_a
  end

  def show; end

  # Manuell erfassen (z. B. telefonische Ausnahmefälle)
  def new
    @reservation = Reservation.new(starts_at: params[:starts_at],
                                   party_size: params[:party_size] || 2,
                                   dining_table: prefilled_table)
    authorize @reservation
    load_tables
  end

  def create
    # Tisch nur aus den erlaubten Tischen (fremder Tisch = 404)
    policy_scope(DiningTable).find(create_params[:dining_table_id]) if create_params[:dining_table_id].present?

    @reservation = Reservation.new(create_params)
    @reservation.user = current_user
    authorize @reservation

    if @reservation.book
      ReservationMailer.confirmation(@reservation).deliver_later
      redirect_to staff_reservation_path(@reservation), notice: "Die Reservation wurde erfasst."
    else
      @alternatives = alternatives if @reservation.slot_taken?
      load_tables
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_tables
  end

  def update
    if @reservation.update_with_lock(permitted_attributes)
      redirect_to staff_reservation_path(@reservation), notice: "Die Reservation wurde gespeichert."
    else
      load_tables
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    # Jemand anderes (Kollege oder Gast) war schneller: nichts wurde gespeichert.
    # Wir zeigen den aktuellen Stand, der Mitarbeiter kann bewusst erneut bearbeiten.
    @reservation.reload
    @conflict = true
    load_tables
    render :edit, status: :conflict
  end

  private

  def set_reservation
    @reservation = Reservation.includes(dining_table: :location).find(params[:id])
    authorize @reservation
  end

  # Stornierte Reservationen sind nur lesbar (der Tisch könnte schon neu vergeben sein)
  def ensure_confirmed
    return if @reservation.confirmed?

    redirect_to staff_reservation_path(@reservation),
                alert: "Stornierte Reservationen können nicht mehr bearbeitet werden."
  end

  def create_params
    params.expect(reservation: %i[dining_table_id starts_at party_size guest_name guest_email guest_phone])
  end

  def reservation_params
    params.expect(reservation: %i[dining_table_id starts_at party_size guest_name guest_email guest_phone lock_version])
  end

  # Ein Tisch darf nur aus den erlaubten Tischen des Benutzers gewählt werden.
  # Ein manipulierter Request mit fremdem Tisch führt zu 404.
  def permitted_attributes
    attributes = reservation_params
    policy_scope(DiningTable).find(attributes[:dining_table_id]) if attributes[:dining_table_id].present?
    attributes
  end

  # Vorausgefüllter Tisch (z. B. aus einem Alternativvorschlag), ebenfalls nur aus erlaubten Tischen
  def prefilled_table
    policy_scope(DiningTable).find(params[:dining_table_id]) if params[:dining_table_id].present?
  end

  # Auswahl im Formular: aktive Tische der eigenen Standorte + der aktuelle Tisch
  def load_tables
    current_table_id = @reservation.dining_table_id_in_database
    @tables = policy_scope(DiningTable).includes(:location).order(:location_id, :number)
                                       .select { |table| table.active? || table.id == current_table_id }
  end

  # Alternativvorschläge nur an Standorten, die der Benutzer verwalten darf
  def alternatives
    return unless @reservation.starts_at && @reservation.party_size

    ReservationSearch.alternatives_for(location: @reservation.dining_table.location,
                                       starts_at: @reservation.starts_at,
                                       party_size: @reservation.party_size,
                                       locations: policy_scope(Location))
  end

  # Die Filter wirken zusätzlich zum Policy-Scope: Ein Mitarbeiter kann sich
  # über eine fremde location_id nie fremde Reservationen anzeigen lassen.
  def filtered(reservations)
    reservations = reservations.preload(dining_table: :location)
    reservations = reservations.at_location(params[:location_id]) if params[:location_id].present?

    if filter_date
      reservations.on_date(filter_date)
    else
      reservations.from_today
    end
  end

  def filter_date
    return if params[:date].blank?

    Date.iso8601(params[:date])
  rescue Date::Error
    nil
  end
end