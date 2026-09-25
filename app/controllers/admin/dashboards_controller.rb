class Admin::DashboardsController < Admin::BaseController
  def show
    @locations = Location.includes(:dining_tables).order(:name)
  end
end