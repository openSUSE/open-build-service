# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += ['webui.js']

theme = CONFIG['theme'] || 'default'
path = "#{Rails.root}/app/themes/#{theme}"
ActionController::Base.prepend_view_path("#{path}/views")
Rails.application.config.assets.paths.unshift("#{path}/assets/images", "#{path}/assets/javascripts", "#{path}/assets/stylesheets")
Sprockets.prepend_path("#{path}/assets/config")
Sprockets.prepend_path("#{path}/assets/images")
Sprockets.prepend_path("#{path}/assets/javascripts")
Sprockets.prepend_path("#{path}/assets/stylesheets")
