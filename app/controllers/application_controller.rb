class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  helper_method :current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def current_user
    @current_user ||= session[:user_id] && User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    redirect_to new_user_session_path, alert: "Bitte anmelden!" if current_user.blank?
  end

  def user_not_authorized
    redirect_to root_path, alert: "keine Berechtigung"
  end

  # Gäste haben kein Konto. Wer eine Reservation gebucht oder mit Code und
  # E-Mail abgerufen hat, ist für diese Reservation in seiner Session "bekannt".
  def remember_reservation(reservation)
    session[:known_reservation_ids] = (Array(session[:known_reservation_ids]) + [ reservation.id ]).uniq
  end

  def reservation_known?(reservation)
    Array(session[:known_reservation_ids]).include?(reservation.id)
  end
end