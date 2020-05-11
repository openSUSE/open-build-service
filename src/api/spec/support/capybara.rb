
Capybara.default_max_wait_time = 6
Capybara.save_path = Rails.root.join('tmp', 'capybara')
Capybara.server = :puma, { Silent: true }
Capybara.disable_animation = true
Capybara.javascript_driver = :desktop

# we use RSPEC_HOST as trigger to use remote selenium
if ENV['RSPEC_HOST'].blank?
  Selenium::WebDriver::Chrome::Service.driver_path = '/usr/lib64/chromium/chromedriver'

  Capybara.register_driver :desktop do |app|
    Capybara::Selenium::Driver.load_selenium
    browser_options = ::Selenium::WebDriver::Chrome::Options.new
    browser_options.args << '--headless'
    browser_options.args << '--no-sandbox' # to run in docker
    browser_options.args << '--window-size=1280,1024'
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  Capybara.register_driver :mobile do |app|
    Capybara::Selenium::Driver.load_selenium
    browser_options = ::Selenium::WebDriver::Chrome::Options.new
    browser_options.args << '--headless'
    browser_options.args << '--no-sandbox' # to run in docker
    browser_options.add_emulation(device_metrics: { width: 320, height: 568, pixelRatio: 1, touch: true })
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end
else
  Capybara.register_driver :desktop do |app|
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(
      'goog:chromeOptions' => {
        'args' => ['--no-sandbox', '--start-maximized']
      },
      browserName: 'chrome'
    )

    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: 'http://selenium:4444/wd/hub',
      desired_capabilities: caps
    )
  end

  Capybara.register_driver :mobile do |app|
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(
      'goog:chromeOptions' => {
        'args' => ['--no-sandbox'],
        mobileEmulation: { deviceMetrics: { width: 320, height: 568, pixelRatio: 1, touch: true } }
      }
    )

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

  Capybara.server_host = '0.0.0.0'
  Capybara.server_port = 3005
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
