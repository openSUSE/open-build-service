# Settings specified here will take precedence over those in config/environment.rb

OBSWebUI::Application.configure do

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new

config.log_level        = :debug


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

config.cache_store = :mem_cache_store, 'localhost:11211', {:namespace => 'obs-webclient-stage', compress: true}

config.action_controller.session = {
    :prefix => "ruby_webclient_stage_session",
    :session_key => "opensuse_webclient_stage_session",
    :secret => "iofupo3i4u6097p09gfsnaf7g8974lh1j3khdlsufdzg9p889234"
}

end

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

CONFIG['frontend_host'] = "api.opensuse.org"
CONFIG['frontend_port'] = 80
CONFIG['frontend_protocol'] = 'http'
CONFIG['frontend_ldap_mode'] = :off
CONFIG['external_frontend_host'] = "api.opensuse.org"
CONFIG['external_frontend_port'] = 443
CONFIG['external_frontend_protocol'] = 'https'

# CONFIG['proxy_auth_mode'] can be one of  'on', 'off' or 'simulate'
CONFIG['proxy_auth_mode'] = :on
CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
