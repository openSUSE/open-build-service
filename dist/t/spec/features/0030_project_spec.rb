require "spec_helper"

RSpec.describe "Project" do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create" do
    within("div#personal-navigation") do
      click_link('Create Home')
    end
    click_button('Accept')
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it "should be able to add repositories" do
    within("div#personal-navigation") do
      click_link('Home Project')
    end
    click_link('Repositories')
    click_link('Add from a Distribution')
    check('repo_openSUSE_Leap_15_1', allow_label_click: true)
    expect(page).to have_content("Successfully added repository 'openSUSE_Leap_15.1'")
  end
end
