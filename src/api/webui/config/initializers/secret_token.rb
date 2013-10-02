# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Webui::Engine.config.secret_token = 'd5c20762e9f94e5992e135f6a201157530a78a109cc849b8f7292b0e9f05c9850810cbb88e375ccf7113b924a2d70d1665840426e196a6ffec69279968c8faf0'

#TODO: Maybe we can get rid of this mechanism and use the above directly?
if File.exist?(Rails.root.join('config', 'secret.key'))
  file = File.open(Rails.root.join('config', 'secret.key'), 'r')
  Webui::Engine.config.secret_token = file.readline()
end

