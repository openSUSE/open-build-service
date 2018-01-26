require "spec_helper"

RSpec.describe "Authentication" do
  after(:example) do
    logout
  end

  it "should be able to sign up" do
    visit "/"
    fill_in 'login', with: 'test_user'
    fill_in 'email', with: 'test_user@openqa.com'
    fill_in 'pwd', with: 'opensuse'
    fill_in 'pwd_confirmation', with: 'opensuse'
    click_button('Sign Up')
    expect(page).to have_content("The account 'test_user' is now active.")
    expect(page).to have_link('link-to-user-home')
  end

  it "should be able to login" do
    login
    expect(page).to have_link('link-to-user-home')
  end
end
