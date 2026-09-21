class Admin::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def authenticate_user!
    redirect_to new_user_session_path, alert: "Bitte anmelden!" if current_user.blank?
  end
end