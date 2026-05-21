ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'logger' # Bundler.require happens too late for logger to be picked up before ActiveSuppport is loaded by rails
