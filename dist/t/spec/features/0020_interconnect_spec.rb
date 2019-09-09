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
    within('div[data-interconnect="openSUSE.org"]') do
      click_button('Connect')
    end
    expect(page).to have_content("Project 'openSUSE.org' was successfully created.")
  end
end
