module ActiveRbacMixins
  # The RegistrationMailerMixin module provides the functionality for the 
  # RegistrationMailer ActionMailer class. You can use it the following way: 
  # Create a file  "model/registration_mailer.rb" in your "RAILS_ENV/app" 
  # directory.
  #
  # Here, create the RegistrationMailer class and import the 
  # RegistrationMailer mixin module, e.g.:
  #
  #   class RegistrationMailer < ActiveRecord::Base
  #     include ActiveRbacMixins::RegistrationMailerMixin
  #
  #     # insert your custom code here
  #   end
  #
  # This will create a ActionMailer class you can then extend to your liking 
  # (i.e. just imagine you had written all the stuff that ActiveRbac's 
  # RegistrationMailer class provides and you can now write some custom lines below it).
  module RegistrationMailerMixin
    # This method is called when the module is included.
    #
    # On inclusion, we do a nifty bit of meta programming and make the
    # including class behave like ActiveRBAC's RegistrationMailer class.
    def self.included(base)
      base.class_eval do
        helper ActionView::Helpers::UrlHelper

        # The mail method for the confirmation email.
        def confirm_registration(user, confirm_url)
          @subject    = ActiveRbac.mailer_subject_confirm_registration
          @recipients = [user.email]
          @from       = ActiveRbac.mailer_from
          @sent_on    = Time.now
          @headers    = ActiveRbac.mailer_headers

          @body       = {
            :user => user,
            :confirm_url => confirm_url
          }
        end

        # The mail method for the "password lost" email.
        def lost_password(user, password)
          @subject    = ActiveRbac.mailer_subject_lost_password
          @recipients = [user.email]
          @from       = ActiveRbac.mailer_from
          @sent_on    = Time.now
          @headers    = ActiveRbac.mailer_headers


          @body       = {
            :user => user,
            :password => password
          }
        end
      end
    end
  end
end