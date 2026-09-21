class UserMailer < ApplicationMailer
  def email_confirmation(user)
    @user = user
    @confirmation_url = email_confirmation_url(token: user.email_confirmation_token)
    Rails.logger.debug "E-Mail-Bestätigungslink: #{@confirmation_url}"

    mail to: user.unconfirmed_email, subject: "Bitte bestätige deine neue E-Mail-Adresse"
  end
end