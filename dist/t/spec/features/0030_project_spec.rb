require "spec_helper"

RSpec.describe "Project" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create" do
    within("div#subheader") do
      click_link('Create Home')
    end
    click_button('Create Project')
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it "should be able to add repositories" do
    within("div#subheader") do
      click_link('Home Project')
    end
    click_link('Repositories')
    click_link('Add repositories')
    check('repo_openSUSE_Leap_42_3')
    expect(page).to have_content("Successfully added repository 'openSUSE_Leap_42.3'")
  end
end
