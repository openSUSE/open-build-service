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

  scenario "create subproject" do
    login user
    visit project_show_path(project: user.home_project_name)
    click_link("Subprojects")

    expect(page).to have_text("This project has no subprojects")
    click_link("create_subproject_link")
    fill_in "project_name", :with => "coolstuff"
    click_button "Create Project"
    expect(page).to have_content("Project '#{user.home_project_name}:coolstuff' was created successfully")

    expect(page.current_path).to match(project_show_path(project: "#{user.home_project_name}:coolstuff"))
    expect(find('#project_title').text).to eq("#{user.home_project_name}:coolstuff")
  end
end
