require 'browser_helper'

RSpec.feature "User's home project creation", type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'moi') }

  scenario 'creating a home project' do
    user.home_project.destroy
    login user
    visit(new_project_path(name: user.home_project_name))

    click_button('Create Project')
    expect(page).to have_content("Project '#{user.home_project_name}' was created successfully")
    expect(user.home_project).not_to be_nil
  end
end
