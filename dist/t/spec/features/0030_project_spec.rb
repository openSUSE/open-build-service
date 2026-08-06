require 'spec_helper'

RSpec.describe 'Project', type: :feature do
  # We consciously want the state of a finished spec to be preserved for the next one
  before(:context) do # rubocop:disable RSpec/BeforeAfterAll
    login
  end

  after(:context) do # rubocop:disable RSpec/BeforeAfterAll
    logout
  end

  it 'is able to create' do
    within('#left-navigation') do
      click_link('Create Your Home Project')
    end
    click_button('Accept')
    expect(page).to have_text("Project 'home:Admin' was created successfully")
  end

  it 'is able to add repositories' do
    # Standard REST API design: Trigger immediate fetch via 'cmd=refresh' query param
    require 'net/http'
    require 'uri'
    uri = URI.parse("#{Capybara.app_host}/distributions?cmd=refresh")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth('Admin', 'opensuse')
    begin
      response = http.request(request)
      puts "Triggered distributions refresh: #{response.code} #{response.body}"
    rescue => e
      puts "Failed to trigger distributions refresh: #{e}"
    end

    Timeout.timeout(300) do
      loop do
        within('#left-navigation') do
          click_link('Your Home Project')
        end
        click_link('Repositories')
        click_link('Add from a Distribution')
        break unless have_text('There are no distributions configured. Maybe you want to connect to one of the public OBS instances?')

        break if have_text('Add Repositories to home:Admin')

        sleep 10
      end
    end
    check('openSUSE Leap 15.5')
    visit current_path
    expect(page).to have_checked_field('openSUSE Leap 15.5')
  end
end
