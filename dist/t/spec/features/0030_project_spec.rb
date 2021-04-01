require "spec_helper"

RSpec.describe "Project", type: :feature do
  before(:context) do
    login
  end

  after(:context) do
    logout
  end

  it "should be able to create" do
    within("#left-navigation") do
      click_link('Create Your Home Project')
    end
    click_button('Accept')
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it "should be able to add repositories" do
    within("#left-navigation") do
      click_link('Your Home Project')
    end
    click_link('Repositories')
    click_link('Add from a Distribution')
    check('repo_openSUSE_Leap_15_3')
    expect(page).to have_content("Successfully added repository 'openSUSE_Leap_15.3'")
  end
end
