require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'

include Capybara::DSL

Capybara.default_max_wait_time = 6

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 30)
end

Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist
