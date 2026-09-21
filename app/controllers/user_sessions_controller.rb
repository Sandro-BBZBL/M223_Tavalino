class UserSessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    credentials = params.expect(user: %i[email_address password])
    user = User.authenticate_by(
      email_address: credentials[:email_address],
      password: credentials[:password]
    )

    if user
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Erfolgreich angemeldet."
    else
      flash[:alert] = "E-Mail oder Passwort ist falsch."
      redirect_to new_user_session_path
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Du wurdest abgemeldet."
  end
end