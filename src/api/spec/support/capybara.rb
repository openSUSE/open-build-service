
Capybara.default_max_wait_time = 6
Capybara.save_path = Rails.root.join('tmp', 'capybara')
Capybara.server = :puma, { Silent: true }
Capybara.disable_animation = true
Capybara.javascript_driver = :desktop
# Attempt to click the associated label element if a checkbox/radio button are non-visible (This is especially useful for Bootstrap custom controls)
Capybara.automatic_label_click = true

Capybara.register_driver :desktop do |app|
  Capybara::Selenium::Driver.load_selenium
  browser_options = ::Selenium::WebDriver::Firefox::Options.new
  browser_options.args << '--headless'
  browser_options.args << '--window-size=1280,1024'
  Capybara::Selenium::Driver.new(app, browser: :firefox, options: browser_options)
end

Capybara.register_driver :mobile do |app|
  Capybara::Selenium::Driver.load_selenium
  browser_options = ::Selenium::WebDriver::Firefox::Options.new
  browser_options.args << '--headless'
  browser_options.args << '--window-size=576,800'
  Capybara::Selenium::Driver.new(app, browser: :firefox, options: browser_options)
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
      save_screenshot("#{example_filename}.png")
    end
  end
end
