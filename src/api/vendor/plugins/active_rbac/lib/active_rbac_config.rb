module ActiveRbacConfig
  # mailer configuration
  config :mailer_from, "ActiveRbac <activerbac@localhost>"
  
  config :mailer_subject_confirm_registration, 'Please confirm your registration'
  config :mailer_subject_lost_password, 'Your new password'
  
  config :mailer_headers, Hash.new
  
  # controller and layout configuration
  config :controller_layout, "application"

  config :controller_registration_signup_fields, Array.new

	# model related configuration
	config :model_default_hash_type, "md5"
end