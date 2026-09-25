# Tischverwaltung je Standort (nur Admins)
class Admin::DiningTablesController < Admin::BaseController
  before_action :set_location
  before_action :set_dining_table, only: %i[edit update]

  def index
    authorize DiningTable
    @dining_tables = @location.dining_tables.order(:number)
    @upcoming_counts = DiningTable.upcoming_reservation_counts(@dining_tables.map(&:id))
  end

  def new
    @dining_table = @location.dining_tables.build(capacity: 2)
    authorize @dining_table
  end

  def create
    @dining_table = @location.dining_tables.build(dining_table_params)
    authorize @dining_table

    if @dining_table.save
      redirect_to admin_location_dining_tables_path(@location), notice: "Der Tisch wurde angelegt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @dining_table.update(dining_table_params)
      redirect_to admin_location_dining_tables_path(@location), notice: "Der Tisch wurde gespeichert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_location
    @location = Location.find(params[:location_id])
  end

  # Der Tisch wird über den Standort gesucht: Ein Tisch eines anderen Standorts in der URL gibt 404.
  def set_dining_table
    @dining_table = @location.dining_tables.find(params[:id])
    authorize @dining_table
  end

  def dining_table_params
    params.expect(dining_table: %i[number capacity active])
  end
end