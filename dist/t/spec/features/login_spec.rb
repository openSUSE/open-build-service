require "spec_helper"
#for getting spec file
require 'net/http'

RSpec.describe "Sign Up & Login" do
  it "should be able to sign up successfully and logout" do
    visit "/"
    expect(page).to have_content("Log In")
    fill_in 'login', with: 'test_user'
    fill_in 'email', with: 'test_user@openqa.com'
    fill_in 'pwd', with: 'opensuse'
    click_button('Sign Up')
    expect(page).to have_content("The account 'test_user' is now active.")
    within("div#subheader") do
      click_link('Logout')
    end
  end
end

RSpec.describe "Create Interconnect as admin and build pckg" do
  it "should be able to add Opensuse Interconnect as Admin" do
    visit "/user/login"
    fill_in 'user_login', with: 'Admin'
    fill_in 'user_password', with: 'opensuse'
    save_screenshot("/tmp/login/l.png")
    click_button('Log In »')
    visit "/configuration/interconnect"
    click_button('openSUSE')
    click_button('Save changes')
  end

  it "should be able to create home project" do
    click_link('Create Home')
    expect(page).to have_content("Create New Project")
    find('input[name="commit"]').click #Create Project
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it "should be able to create a new package from OBS:Server:Unstable/build/build.spec" do
    File.write("build.spec", Net::HTTP.get(URI.parse("https://api.opensuse.org/public/source/OBS:Server:Unstable/build/build.spec")))
    find('img[title="Create package"]').click
    expect(page).to have_content("Create New Package for home:Admin")
    fill_in 'name', with: 'testpackage'
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Package 'testpackage' was created successfully")
    find('img[title="Add file"]').click
    expect(page).to have_content("Add File to")
    attach_file("file", "build.spec")
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Source Files")
  end

  it "should be able to add build targets from existing repos" do
    click_link('build targets')
    expect(page).to have_content("openSUSE distributions")
    check('repo_openSUSE_Tumbleweed')
    check('repo_openSUSE_Leap_42.1')
    find('input[id="submitrepos"]').click #Add selected repositories
    expect(page).to have_content("Successfully added repositories")
    expect(page).to have_content("openSUSE_Leap_42.1 (x86_64)")
    expect(page).to have_content("openSUSE_Tumbleweed (i586, x86_64)")
  end

  it "should be able to Overview Build Results" do
    click_link('Overview')
    expect(page).to have_content("Build Results")
  end
end