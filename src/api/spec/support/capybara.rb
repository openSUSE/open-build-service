require 'capybara/poltergeist'

Capybara.default_max_wait_time = 6
Capybara.save_path = Rails.root.join('tmp', 'capybara')

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 30)
end

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_ACCEPT' => 'text/html' })
end

Capybara.javascript_driver = :poltergeist

# Automatically save the page a test fails
RSpec.configure do |config|
  config.after(:each, type: :feature) do
    example_filename = RSpec.current_example.full_description
    example_filename = example_filename.tr(' ', '_')
    example_filename += '.html'
    example_filename = File.expand_path(example_filename, Capybara.save_path)
    if RSpec.current_example.exception.present?
      save_page(example_filename)
    elsif File.exist?(example_filename)
      File.unlink(example_filename)
    end
  end
end
