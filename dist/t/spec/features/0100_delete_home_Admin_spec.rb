require "spec_helper"

RSpec.describe "Delete project home:Admin" do

  it "should be able to login as user Admin" do
    obs_login("Admin","opensuse")
  end

  it "should be able to execute delete" do
    visit("/project/show/home:Admin")
    click_link("Delete project")
  end

end
