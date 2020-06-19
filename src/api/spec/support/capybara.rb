require 'capybara/apparition'

Capybara.default_max_wait_time = 6
Capybara.save_path = Rails.root.join('tmp', 'capybara')
Capybara.server = :puma, { Silent: true }
Capybara.disable_animation = true
Capybara.javascript_driver = :desktop
# Attempt to click the associated label element if a checkbox/radio button are non-visible (This is especially useful for Bootstrap custom controls)
Capybara.automatic_label_click = true

Capybara.register_driver :desktop do |app|
  options = { window_size: [1280, 1024] }
  Capybara::Apparition::Driver.new(app, options)
end

Capybara.register_driver :mobile do |app|
  options = { window_size: [320, 568] }
  Capybara::Apparition::Driver.new(app, options)
end

# Automatically save the page a test fails
RSpec.configure do |config|
  config.before(:suite) do
    FileUtils.rm_rf(File.join(Capybara.save_path, '.'), secure: true)
  end

  config.after(:each, type: :feature) do
    if RSpec.current_example.exception.present?
      example_filename = RSpec.current_example.full_description
      example_filename = example_filename.gsub(/[^0-9A-Za-z_]/, '_')
      example_filename = File.expand_path(example_filename, Capybara.save_path)
      save_page("#{example_filename}.html")
      # rubocop:disable Lint/Debugger
      # TODO: The RuboCop comments can be removed once this is merged upstream: https://github.com/rubocop-hq/rubocop/pull/7853
      save_screenshot("#{example_filename}.png", full: true)
      # rubocop:enable Lint/Debugger
    end
  end
end
