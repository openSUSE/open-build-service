# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# https://github.com/rails/sprockets/issues/581
Rails.application.config.assets.configure do |env|
  env.export_concurrent = false
end

