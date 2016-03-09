require "spec_helper"

RSpec.describe "Login" do

  it "should be able to sign up" do
    visit "http://localhost:3000/"
    expect(page).to have_content("Log In")
  end

end
