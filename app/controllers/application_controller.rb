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
end