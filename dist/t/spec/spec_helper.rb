# OBS Appliance spec helper.
#
# for capybara rspec support
require 'support/capybara'

SCREENSHOT_DIR = "/tmp/rspec_screens".freeze

RSpec.configure do |config|
  config.before(:suite) do
    FileUtils.rm_rf(SCREENSHOT_DIR)
    FileUtils.mkdir_p(SCREENSHOT_DIR)
  end
  config.after(:each) do |example|
    if example.exception
      take_screenshot(example)
      dump_page(example)
    end
  end
  config.fail_fast = 1
end

def dump_page(example)
  filename = File.basename(example.metadata[:file_path])
  line_number = example.metadata[:line_number]
  dump_name = "dump-#{filename}-#{line_number}.html"
  dump_path = File.join(SCREENSHOT_DIR, dump_name)
  page.save_page(dump_path)
end

def take_screenshot(example)
  filename = File.basename(example.metadata[:file_path])
  line_number = example.metadata[:line_number]
  screenshot_name = "screenshot-#{filename}-#{line_number}.png"
  screenshot_path = File.join(SCREENSHOT_DIR, screenshot_name)
  page.save_screenshot(screenshot_path, full: true)
end

def login
  visit "/session/new"
  within('#loginform') do
    fill_in 'user-login', with: 'Admin'
    fill_in 'user-password', with: 'opensuse'
    click_button('Log In')
  end
  expect(page).to have_link('top-navigation-profile-dropdown')
end

def logout
  click_link('top-navigation-profile-dropdown')
  within("#top-navigation-area") do
    click_link('Logout')
  end
  expect(page).to have_no_link('top-navigation-profile-dropdown')
end
