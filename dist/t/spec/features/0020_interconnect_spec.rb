require "spec_helper"

RSpec.describe "Create Interconnect as admin and build package" do

  it "should be able to login as user 'Admin'" do
    obs_login("Admin","opensuse")
  end

  it "should be able to add Opensuse Interconnect as Admin" do
    visit "/configuration/interconnect"
    click_button('openSUSE')
    click_button('Save changes')
  end

end
