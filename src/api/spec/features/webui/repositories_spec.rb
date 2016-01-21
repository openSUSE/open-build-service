require "browser_helper"

RSpec.feature "Repositories", :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user) }

  scenario "add" do
    login user
    visit "/project/add_repository_from_default_list/#{user.home_project_name}"

    check 'repo_Base_repo'
    click_button 'Add selected repositories'

    expect(page).to have_text("Successfully added repositories")
    expect(page).to have_css("#Base_repo")
  end
end
