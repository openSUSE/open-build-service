# This ActionMailer sends the mails and is used by the RegistrationController.
# Currently, only two kinds of email can be sent.
# 
# * confirm_registration - is sent on users' registrations. It contains a link
#     to the confirmation URL.
# * lost_password - is sent on "password lost" requests of users. It contains
#     the new one-time password.
class RegistrationMailer < ActionMailer::Base
  helper ActionView::Helpers::UrlHelper
  
  # The mail method for the confirmation email.
  def confirm_registration(user, confirm_url)
    @subject    = ActiveRbacConfig.config :mailer_subject_confirm_registration
    @recipients = [user.email]
    @from       = ActiveRbacConfig.config :mailer_from
    @sent_on    = Time.now
    @headers    = ActiveRbacConfig.config :mailer_headers
  
    @body       = {
      :user => user,
      :confirm_url => confirm_url
    }
  end

  # The mail method for the "password lost" email.
  def lost_password(user, password)
    @subject    = ActiveRbacConfig.config :mailer_subject_lost_password
    @recipients = [user.email]
    @from       = ActiveRbacConfig.config :mailer_from
    @sent_on    = Time.now
    @headers    = ActiveRbacConfig.config :mailer_headers
  
  
    @body       = {
      :user => user,
      :password => password
    }
  end
end