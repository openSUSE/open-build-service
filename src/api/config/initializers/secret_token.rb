# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

# obs-api package is generating this file during installation
if File.exists? "#{Rails.root}/config/secret.key"
  OBSApi::Application.config.secret_key_base = File.read "#{Rails.root}/config/secret.key"
elsif Rails.env.production?
  raise "Missing config/secret.key file!"
else
  # for development and test environment
  OBSApi::Application.config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'
end
