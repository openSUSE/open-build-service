require 'spec_helper'

RSpec.describe 'Project', type: :feature do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it 'should be able to create' do
    within('#left-navigation') do
      click_link('Create Your Home Project')
    end
    click_button('Accept')
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it 'should be able to add repositories' do
    within('#left-navigation') do
      click_link('Your Home Project')
    end
    click_link('Repositories')
    click_link('Add from a Distribution')
    check('openSUSE Leap 15.3')
    visit current_path
    expect(page).to have_checked_field('openSUSE Leap 15.3')
  end
end
