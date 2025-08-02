require 'spec_helper'

RSpec.describe 'Project', type: :feature do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it 'is able to create' do
    within('#left-navigation') do
      click_link('Create Your Home Project')
    end
    click_button('Accept')
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it 'is able to add repositories' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('Repositories')
    click_link('Add from a Distribution')
    Timeout.timeout(120) do
      loop do
        break unless have_content('There are no distributions configured. Maybe you want to connect to one of the public OBS instances?')

        # If we found our record we sleep for 0.25 seconds and try again.
        sleep 10
        reload_page
      end
    end
    check('openSUSE Leap 15.5')
    visit current_path
    expect(page).to have_checked_field('openSUSE Leap 15.5')
  end
end
