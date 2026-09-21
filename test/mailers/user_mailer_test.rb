require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "email_confirmation" do
    user = users(:staff)
    user.stage_email_change("neu@example.com")

    mail = UserMailer.email_confirmation(user)

    assert_equal "Bitte bestätige deine neue E-Mail-Adresse", mail.subject
    assert_equal [ "neu@example.com" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match user.email_confirmation_token, mail.text_part.decoded
  end
end