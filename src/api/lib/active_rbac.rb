module ActiveRbac
  # mailer options  
  @@mailer_from = "ActiveRbac <activerbac@localhost>"
  mattr_accessor :mailer_from
  
  @@mailer_subject_confirm_registration = "Please confirm your registration"
  mattr_accessor :mailer_subject_confirm_registration
  @@mailer_subject_lost_password = "Your new password"
  mattr_accessor :mailer_subject_lost_password
  @@mailer_headers = Hash.new
  mattr_accessor :mailer_headers 
  
  # controller and layout options
  @@controller_layout = "application"
  mattr_accessor :controller_layout

  @@controller_registration_signup_fields = Array.new
  mattr_accessor :controller_registration_signup_fields
  # model related options
  @@model_default_hash_type = "md5"
  mattr_accessor :model_default_hash_type
  
  # anonymous user default configuration
  @@anonymous_user_login = 'anonymous'
  mattr_accessor :anonymous_user_login
  @@anonymous_user_email = 'nobody@localhost'
  mattr_accessor :anonymous_user_email
  @@anonymous_user_roles = Array.new
  mattr_accessor :anonymous_user_roles
  @@anonymous_user_groups = Array.new
  mattr_accessor :anonymous_user_groups
end