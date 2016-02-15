require "browser_helper"

RSpec.feature "User's home project creation", type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'moi') }

  scenario "login with home project shows a link to it" do
    login user
    expect(page).to have_content "#{user.login} | Home Project | Logout"
  end

  scenario "login without home project shows a link to create it" do
    Project.find_by(name: user.home_project_name).destroy
    login user
    expect(page).to have_content "#{user.login} | Create Home | Logout"
  end

  scenario "creating a home project" do
    Project.find_by(name: user.home_project_name).destroy
    login user
    visit(new_project_path(name: user.home_project_name))
  
    click_button("Create Project")
    expect(page).to have_content("Project '#{user.home_project_name}' was created successfully")
    expect(page).to have_content "#{user.login} | Home Project | Logout"
    project = Project.find_by(name: user.home_project_name)
    expect(project).not_to be_nil
  end
end
