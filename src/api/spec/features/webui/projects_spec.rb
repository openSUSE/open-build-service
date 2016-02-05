require "browser_helper"

RSpec.feature "Projects", :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user) }

  scenario "project show" do
    login user
    visit project_show_path(project: user.home_project_name)
    expect(page).to have_text("Packages (0)")
    expect(page).to have_text("This project does not contain any packages")
  end

  scenario "create package" do
    login user
    visit project_show_path(project: user.home_project_name)
    click_link("Create package")
    expect(page).to have_text("Create New Package for #{user.home_project_name}")
    fill_in "name", :with => "coolstuff"
    click_button "Save changes"
  end
end
