class PasswordsController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attrs = params.expect(user: %i[current_password password password_confirmation])

    if !@user.authenticate(attrs[:current_password])
      @user.errors.add(:current_password, "ist falsch")
      render :edit, status: :unprocessable_entity
    elsif attrs[:password].blank?
      @user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_entity
    elsif @user.update(password: attrs[:password], password_confirmation: attrs[:password_confirmation])
      reset_session
      session[:user_id] = @user.id
      redirect_to profile_path, notice: "Passwort geändert."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end