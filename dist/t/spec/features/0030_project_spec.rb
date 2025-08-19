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
    sleep(5)
    click_link('Add from a Distribution')
    Timeout.timeout(300) do
      loop do
        break unless have_content('There are no distributions configured. Maybe you want to connect to one of the public OBS instances?')

        break if have_content('Add Repositories to home:Admin')

        sleep 10
        refresh
      end
    end
    check('openSUSE Leap 15.5')
    visit current_path
    expect(page).to have_checked_field('openSUSE Leap 15.5')
  end
end
