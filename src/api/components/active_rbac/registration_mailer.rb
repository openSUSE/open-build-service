require_dependency 'active_rbac/configuration'

# We have to modifiy the ActionMailer::Base class a bit to add a
# uses_component_template_root function.
#
# TODO: Move this to the "general fixup" directory
module ActionMailer # :nodoc:
  class Base # :nodoc:
    def Base::uses_component_template_root # :nodoc:
      path_of_calling_mailer = File.dirname(caller[0].split(/:\d+:/).first)
      self.template_root = path_of_calling_mailer
    end
  end
end

# This ActionMailer sends the mails and is used by the RegistrationController.
# Currently, only two kinds of email can be sent.
# 
# * confirm_registration - is sent on users' registrations. It contains a link
#     to the confirmation URL.
# * lost_password - is sent on "password lost" requests of users. It contains
#     the new one-time password.
class RegistrationMailer < ActionMailer::Base
  uses_component_template_root
  
  helper ActionView::Helpers::UrlHelper
  
  # The mail method for the confirmation email.
  def confirm_registration(user, confirm_url)
    @subject    = config.mailer[:subjects][:confirm_registration]
    @recipients = [user.email]
    @from       = config.mailer[:from]
    @sent_on    = Time.now
    @headers    = config.mailer[:headers]
  
    @body       = {
      :user => user,
      :confirm_url => confirm_url
    }
  end

  # The mail method for the "password lost" email.
  def lost_password(user, password)
    @subject    = config.mailer[:subjects][:lost_password]
    @recipients = [user.email]
    @from       = config.mailer[:from]
    @sent_on    = Time.now
    @headers    = config.mailer[:headers]
  
  
    @body       = {
      :user => user,
      :password => password
    }
  end
  
  protected
  
    # An alias to self.config
    def config; self.class.config; end
    
    def self.config
      ActiveRbac::Configuration
    end
end