class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_area
  after_action :verify_authorized

  private

  def authorize_admin_area
    authorize :admin, :access?
  end
end