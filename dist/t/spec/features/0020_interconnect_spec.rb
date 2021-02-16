require "spec_helper"

RSpec.describe "Interconnect", type: :feature do
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
    sleep(10)
    visit "/project/show/openSUSE.org"

    expect(page).to have_content("Standard OBS instance at build.opensuse.org")
    expect(page).to have_content("https://api.opensuse.org/public")
  end
end
