# This class is a container for the ActiveRBAC components configuration setup.
# There is an accessor method for each "aspect" of this component that returns a
# hash representing a tree. You can access the following values.
#
# * mailer                 The configuration hash for the mailer classes.
# * mailer[:template_root] The template path the mailer will look in.
# * mailer[:subjects]      A hash of the subjects to use. Currently used: _confirm_registration_, _lost_password_
# * mailer[:headers]       A hash with additional headers to set in the emails.
# * controller						 The configuration for the controllers.
# * controller[:layout]    The path to the layout to use. Defaults to '../app/views/layouts/application'.
#
# == Configuration
#
# If you want to change the configuration, you have to put it into 
# "config/active_rbac_config.rb". An example:
#
# ActiveRbac::Configuration.mailer[:from] = 'foo <foo@localhost>'
class ActiveRbac::Configuration
  @@mailer = {}

  @@mailer[:template_root] = 'components'
  @@mailer[:from] = 'ActiveRBAC <activerbac@localhost>'

  @@mailer[:subjects] = {}
  @@mailer[:subjects][:confirm_registration] = 'Please confirm your registration'
  @@mailer[:subjects][:lost_password] = 'Your new password'

  # Additional headers to set besides Subject: and To:
  @@mailer[:headers] = {}
	
  @@controller = {}
  @@controller[:layout] = '../app/views/layouts/html'
  @@controller[:registration] = {}
  @@controller[:registration][:signup_fields] = []
	
  @@model = {}
  @@model[:default_hash_type] = 'md5'
	
  @@signup_fields = []

  class << self
    def mailer # :nodoc:
      @@mailer
    end

    def controller # :nodoc:
    	@@controller
    end

    def model # :nodoc:
    	@@model
    end
  end
end

# Require the configuration for the active_rbac component
require_dependency 'config/active_rbac_config'
