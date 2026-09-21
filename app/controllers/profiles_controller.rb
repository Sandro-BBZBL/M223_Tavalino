class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if @user.update(params.expect(user: [:name]))
      redirect_to profile_path, notice: "Profil aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end
end