require "spec_helper"

RSpec.describe "Sign Up & Login" do

  it "should be able to sign up successfully" do
    visit "/"
    expect(page).to have_content("Log In")
    fill_in 'login', with: 'test_user'
    fill_in 'email', with: 'test_user@openqa.com'
    fill_in 'pwd', with: 'opensuse'
    click_button('Sign Up')
    expect(page).to have_content("The account 'test_user' is now active.")
  end

end