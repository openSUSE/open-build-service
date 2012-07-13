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

done

# Host name gets changed by obsapisetup on each boot
FRONTEND_HOST = "localhost"
FRONTEND_PORT = 81
FRONTEND_PROTOCOL = 'http'

# use this when the users see the api at another url (for rpm-, file-downloads)
#EXTERNAL_FRONTEND_HOST = "api.opensuse.org"

BUGZILLA_HOST = nil
DOWNLOAD_URL = "http://localhost:82"

# ICHAIN_MODE can be one of  'on', 'off' or 'simulate'
ICHAIN_MODE = "off"

BASE_NAMESPACE = nil
