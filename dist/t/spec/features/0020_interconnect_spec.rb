require "spec_helper"

RSpec.describe "Interconnect" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create link" do
    visit "/configuration/interconnect"
    # Don't wait for the javascript text replacement...
    page.execute_script("$('input[type=\"submit\"]').prop('disabled', false)")
    click_button('Save changes')
    expect(page).to have_content("Project 'openSUSE.org' was created successfully")
  end
end
