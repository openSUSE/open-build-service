# This file is used by Rack-based servers to start the application.

require ::File.expand_path('config/environment', __dir__)
map Rails.application.config.relative_url_root || '/' do
  run OBSApi::Application
end
