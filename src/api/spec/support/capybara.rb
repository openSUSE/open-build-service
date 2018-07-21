
Capybara.default_max_wait_time = 6
Capybara.save_path = Rails.root.join('tmp', 'capybara')

# we use RSPEC_HOST as trigger to use remote selenium
if ENV['RSPEC_HOST'].blank?
  Selenium::WebDriver::Chrome.driver_path = '/usr/lib64/chromium/chromedriver'

  Capybara.register_driver :selenium_chrome_headless do |app|
    Capybara::Selenium::Driver.load_selenium
    browser_options = ::Selenium::WebDriver::Chrome::Options.new
    browser_options.args << '--headless'
    browser_options.args << '--no-sandbox' # to run in docker
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  Capybara.javascript_driver = :selenium_chrome_headless
else
  caps = Selenium::WebDriver::Remote::Capabilities.chrome(
    'goog:chromeOptions' => {
      'args' => ['--no-sandbox']
    },
     browserName: 'chrome'
  )

  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: 'http://selenium:4444/wd/hub',
      desired_capabilities: caps
    )
  end
  Capybara.configure do |config|
    config.app_host = "http://#{ENV['RSPEC_HOST']}:3005"
  end

  Capybara.server = :puma, { Silent: true }
  Capybara.server_host = '0.0.0.0'
  Capybara.server_port = 3005
  Capybara.javascript_driver = :chrome
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
