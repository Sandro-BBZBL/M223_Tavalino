class EmailConfirmationsController < ApplicationController
  def show
    user = User.find_by(email_confirmation_token: params[:token])

    if user&.confirm_email_change
      redirect_to(current_user ? profile_path : new_user_session_path,
                  notice: "Deine neue E-Mail-Adresse ist bestätigt.")
    else
      redirect_to root_path, alert: "Der Bestätigungslink ist ungültig oder abgelaufen."
    end
  end
end