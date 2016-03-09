require "spec_helper"

RSpec.describe "Login" do

  it "should be able to sign up" do
    visit "/"
    expect(page).to have_content("Log In")
  end

end
