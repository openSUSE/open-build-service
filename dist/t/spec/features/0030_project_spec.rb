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
    # Trigger refresh of distributions...
    post '/distributions/refresh'
    expect(response).to be_success
    visit '/'
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('Repositories')
    click_link('Add from a Distribution')
    expect(page).to have_text('Add Repositories to home:Admin')
    check('openSUSE Leap 15.5')
    visit current_path
    expect(page).to have_checked_field('openSUSE Leap 15.5')
  end
end
