# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

# obs-api package is generating this file during installation
if File.exist? "#{Rails.root}/config/secret.key"
  OBSApi::Application.config.secret_key_base = File.read "#{Rails.root}/config/secret.key"
elsif Rails.env.production?
  raise 'Missing config/secret.key file!'
end
