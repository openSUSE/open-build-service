# This ActionMailer sends the mails and is used by the RegistrationController.
# Currently, only two kinds of email can be sent.
# 
# * confirm_registration - is sent on users' registrations. It contains a link
#     to the confirmation URL.
# * lost_password - is sent on "password lost" requests of users. It contains
#     the new one-time password.
#
# The RegistrationMailer ActionMailer class mixes in the 
# "ActiveRbacMixins::RegistrationMailerMixin" module.
# This module contains the actual implementation. It is kept there so
# you can easily provide your own registration mailer files without having to 
# all lines from the engine's directory
class RegistrationMailer < ActionMailer::Base
  include ActiveRbacMixins::RegistrationMailerMixin
end