# frozen_string_literal: true

# OmniAuth configuration for LDAP authentication
#
# This initializer configures OmniAuth to use LDAP authentication with the
# omniauth-ldap strategy. When enabled, users can authenticate via LDAP
# and OBS will automatically create/update their accounts using proxy_auth_mode.
#
# Configuration is read from config/options.yml under the 'ldap' section.

Rails.application.config.middleware.use OmniAuth::Builder do
  # Only configure LDAP provider if enabled in options.yml
  if CONFIG['ldap']&.dig('enabled')
    ldap_config = CONFIG['ldap']

    provider :ldap,
             # Connection settings
             host: ldap_config['host'] || 'ldap.example.com',
             port: ldap_config['port'] || 389,
             method: ldap_config['encryption']&.to_sym || :plain,
             base: ldap_config['base'] || 'dc=example,dc=com',
             uid: ldap_config['uid_attribute'] || 'uid',

             # Bind credentials for searching LDAP
             bind_dn: ldap_config['bind_dn'],
             password: ldap_config['bind_password'],

             # User search settings
             filter: ldap_config['user_filter'] || '(objectClass=person)',

             # Attribute mapping (what to retrieve from LDAP)
             # These will be available in auth_hash.info
             name_proc: lambda { |name|
               # Strip domain if present (@example.com)
               name.gsub(/@.*$/, '')
             },

             # Additional options
             title: ldap_config['title'] || 'LDAP',
             connect_timeout: ldap_config['timeout'] || 15

    Rails.logger.info "OmniAuth-LDAP configured: #{ldap_config['host']}:#{ldap_config['port']}"
  else
    Rails.logger.info 'OmniAuth-LDAP: LDAP authentication is disabled in config/options.yml'
  end
end

# OmniAuth configuration
OmniAuth.config.tap do |config|
  # Only allow POST requests to OmniAuth endpoints for security
  config.allowed_request_methods = [:post]

  # Log OmniAuth errors
  config.logger = Rails.logger

  # Disable OmniAuth's default error handling to use our own
  config.on_failure = proc { |env|
    OmniAuthCallbacksController.action(:failure).call(env)
  }
end
