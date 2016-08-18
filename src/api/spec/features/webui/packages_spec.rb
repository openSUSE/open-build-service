require "browser_helper"

RSpec.feature "Packages", :type => :feature, :js => true do
  it_behaves_like 'user tab' do
    let(:package) {
      create(:package, name: "group_test_package",
        project_id: user_tab_user.home_project.id)
    }
    let!(:maintainer_user_role) { create(:relationship, package: package, user: user_tab_user) }
    let(:project_path) { package_show_path(project: user_tab_user.home_project, package: package) }
  end

  let!(:user) { create(:confirmed_user, login: "package_test_user") }
  let!(:package) { create(:package_with_file, name: "test_package", project: user.home_project) }
  let(:other_user) { create(:confirmed_user, login: "other_package_test_user") }
  let!(:other_users_package) { create(:package_with_file, name: "branch_test_package", project: other_user.home_project) }

  describe "branching a package" do
    after do
      # Cleanup backend
      if CONFIG["global_write_through"]
        Suse::Backend.delete("/source/#{CGI.escape(other_user.home_project_name)}")
        Suse::Backend.delete("/source/#{CGI.escape(user.branch_project_name(other_user.home_project_name))}")
      end
    end

    scenario "from another user's project" do
      login user
      visit package_show_path(project: other_user.home_project, package: other_users_package)

      click_link("Branch package")
      click_button("Ok")

      expect(page).to have_text("Successfully branched package")
      expect(page.current_path).to eq(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package))
    end
  end

  scenario "deleting a package" do
    login user
    visit package_show_path(package: package, project: user.home_project)
    click_link("delete-package")
    expect(find("#del_dialog")).to have_text("Do you really want to delete this package?")
    click_button('Ok')
    expect(find("#flash-messages")).to have_text("Package was successfully removed.")
  end

  scenario "requesting package deletion" do
    login user
    visit package_show_path(package: other_users_package, project: other_user.home_project)
    click_link("Request deletion")
    expect(page).to have_text("Do you really want to request the deletion of package ")
    click_button("Ok")
    expect(page).to have_text("Created repository delete request")
    find("a", text: /repository delete request \d+/).click
    expect(page.current_path).to match("/request/show/\\d+")
  end
end
