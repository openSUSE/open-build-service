require "spec_helper"

RSpec.describe "Interconnect" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create link" do
    visit "/interconnects/new"
    # Don't wait for the javascript text replacement...
    page.execute_script("$('input[type=\"submit\"]').prop('disabled', false)")
    click_button('Create Remote project')
    expect(page).to have_content("Project 'openSUSE.org' was successfully created.")
  end
end
