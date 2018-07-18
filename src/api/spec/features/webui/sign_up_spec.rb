require 'browser_helper'

RSpec.feature 'Sign up', type: :feature, js: true do
  let!(:user) { build(:user) }

  scenario 'User' do
    visit root_path

    fill_in 'login', with: 'eisendieter'
    fill_in 'email', with: 'dieter.eilts@werder.de'
    fill_in 'pwd', with: 'alemao'
    fill_in 'pwd_confirmation', with: 'alemao'
    click_button('Sign Up')

    expect(page).to have_text("The account 'eisendieter' is now active.")
    assert User.find_by(login: 'eisendieter').is_active?
  end

  scenario 'User with confirmation' do
    # Configure confirmation for signups
    allow_any_instance_of(::Configuration).to receive(:registration).and_return('confirmation')

    visit root_path

    fill_in 'login', with: user.login
    fill_in 'email', with: user.email
    fill_in 'pwd', with: 'alemao'
    fill_in 'pwd_confirmation', with: 'alemao'
    click_button('Sign Up')

    expect(page).to have_text('Thank you for signing up! An admin has to confirm your account now. Please be patient.')
  end

  scenario 'User is denied' do
    # Deny signups
    allow_any_instance_of(::Configuration).to receive(:registration).and_return('deny')

    visit user_register_user_path

    expect(page).to have_text('Sorry, sign up is disabled')
  end
end
