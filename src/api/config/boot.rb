unless File.exist?(File.expand_path('../Gemfile.in', __dir__))
  ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

  require 'bundler/setup' # Set up gems listed in the Gemfile.
end
