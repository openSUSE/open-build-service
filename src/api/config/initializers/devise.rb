# frozen_string_literal: true

# Devise with the iChain proxy strategy (devise_ichain_authenticatable).
require 'devise/orm/active_record'

Devise.setup do |config|
  # Devise lowercases and strips :email on every save by default. OBS stores emails as entered,
  # so turn both off.
  config.case_insensitive_keys = []
  config.strip_whitespace_keys = []

  # The gem passes these request headers to User.for_ichain_username as attributes.
  # The keys must match what User.for_ichain_username reads: email, firstname, lastname.
  config.ichain_attribute_headers = {
    email: 'HTTP_X_EMAIL',
    firstname: 'HTTP_X_FIRSTNAME',
    lastname: 'HTTP_X_LASTNAME'
  }

  # Test mode makes the iChain strategy accept requests without checking the proxy headers.
  # Never set this to true in production. Doing so lets any client that can reach the app
  # log in as any user by sending a forged username header. Keep it false outside of tests.
  config.ichain_test_mode = false
end
