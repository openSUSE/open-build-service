require 'spec_helper'

RSpec.describe 'Authentication', type: :feature do
  after do
    logout
  end

  it 'is able to sign up' do
    visit '/'
    within('.sign-up') do
      fill_in 'login', with: 'test_user'
      fill_in 'email', with: 'test_user@openqa.com'
      fill_in 'pwd', with: 'opensuse'
      fill_in 'pwd_confirmation', with: 'opensuse'
      click_button('Sign Up')
    end
    expect(page).to have_content("The account 'test_user' is now active.")
    expect(page).to have_link('top-navigation-profile-dropdown')
  end

  it 'is able to login' do
    login
    expect(page).to have_link('top-navigation-profile-dropdown')
  end
end
