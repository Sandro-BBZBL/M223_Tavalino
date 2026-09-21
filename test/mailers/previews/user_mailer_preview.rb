# Vorschau unter http://localhost:3000/rails/mailers/user_mailer/email_confirmation
class UserMailerPreview < ActionMailer::Preview
  def email_confirmation
    user = User.first || User.new(name: "Vorschau", email_address: "vorschau@example.com")
    user.stage_email_change("neue-adresse@example.com") # nur im Speicher, wird nicht gespeichert
    UserMailer.email_confirmation(user)
  end
end