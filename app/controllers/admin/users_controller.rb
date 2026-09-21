class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[edit update]
  before_action :set_locations, only: %i[edit update]

  def index
    @users = User.includes(:locations).order(:name)
    authorize @users, :index?
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    if removing_own_admin_role?
      @user.errors.add(:role, "kannst du bei dir selbst nicht ändern, sonst sperrst du dich aus")
      render :edit, status: :unprocessable_entity
    elsif @user.update(user_params)
      redirect_to admin_users_path, notice: "Benutzer aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_locations
    @locations = Location.order(:name)
  end

  def removing_own_admin_role?
    @user == current_user && user_params[:role].present? && user_params[:role] != "admin"
  end

  def user_params
    params.expect(user: [ :name, :email_address, :role, { location_ids: [] } ])
  end
end