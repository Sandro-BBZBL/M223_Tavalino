class EmailChangesController < ApplicationController
  before_action :authenticate_user!

  def create
    @user = current_user

    User.transaction do
      @user.stage_email_change(params[:new_email].to_s)
      @user.save!
      UserMailer.email_confirmation(@user).deliver_now
    end

    redirect_to profile_path,
                notice: "Wir haben einen Bestätigungslink an #{@user.unconfirmed_email} gesendet."
  rescue ActiveRecord::RecordInvalid
    render "profiles/edit", status: :unprocessable_entity
  end
end