# Settings specified here will take precedence over those in config/environment.rb

OBSWebUI::Application.configure do

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

end

# Host name gets changed by obsapisetup on each boot
CONFIG['frontend_host'] = "localhost"
CONFIG['frontend_port'] = 444
CONFIG['frontend_protocol'] = 'https'

# use this when the users see the api at another url (for rpm-, file-downloads)
#CONFIG['external_frontend_host'] = "api.opensuse.org"

CONFIG['bugzilla_host'] = nil
CONFIG['download_url'] = "http://localhost:82"

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
CONFIG['ichain_mode'] = "off"

CONFIG['base_namespace'] =  nil

