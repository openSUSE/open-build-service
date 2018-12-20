EffectiveDatatables.setup do |config|
  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If it raises an exception or returns false, an Effective::AccessDenied Error will be raised
  #
  # Use via Proc:
  # Proc.new { |controller, action, resource| authorize!(action, resource) }       # CanCan
  # Proc.new { |controller, action, resource| can?(action, resource) }             # CanCan with skip_authorization_check
  # Proc.new { |controller, action, resource| authorize "#{action}?", resource }   # Pundit
  # Proc.new { |controller, action, resource| current_user.is?(:admin) }           # Custom logic
  #
  # Use via Boolean:
  # config.authorization_method = true  # Always authorized
  # config.authorization_method = false # Always unauthorized
  #
  # Use via Method (probably in your application_controller.rb):
  # config.authorization_method = :my_authorization_method
  # def my_authorization_method(resource, action)
  #   true
  # end
  config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }

  # Default number of entries shown per page
  # Valid options are: 5, 10, 25, 50, 100, 250, 500, :all
  config.default_length = 25

  # Default class used on the <table> tag
  config.html_class = 'table table-hover'

  # Log search/sort information to the console
  config.debug = true

  # If a user has previously visited this page and is returning, use the cookie to restore last session
  # Irregardless of this setting, effective_datatables still uses a cookie to function
  config.save_state = true

  # String size. Final byte size is about 1.5 times bigger, after rails signs it
  config.max_cookie_size = 2000

end
