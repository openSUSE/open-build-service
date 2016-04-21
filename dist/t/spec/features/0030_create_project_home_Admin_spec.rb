require "spec_helper"

RSpec.describe "Create project home:Admin" do


  it "should be able to login as user 'Admin'" do
    obs_login('Admin','opensuse')
  end

  it "should be able to create home project" do
    click_link('Create Home')
    expect(page).to have_content("Create New Project")
    find('input[name="commit"]').click #Create Project
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

end
