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

  describe "branching a package" do
    let!(:user) { create(:confirmed_user, login: "package_test_user") }
    let(:other_user) { create(:confirmed_user, login: "other_package_test_user") }
    let!(:package) { create(:package_with_file, name: "branch_test_package", project: other_user.home_project) }

    after do
      # Cleanup backend
      if CONFIG["global_write_through"]
        Suse::Backend.delete("/source/#{CGI.escape(other_user.home_project_name)}")
        Suse::Backend.delete("/source/#{CGI.escape(user.branch_project_name(other_user.home_project_name))}")
      end
    end

    scenario "from another user's project" do
      login user
      visit package_show_path(project: other_user.home_project, package: package)

      # This needs global write through
      click_link("Branch package")
      click_button("Ok")

      expect(page).to have_text("Successfully branched package")
      expect(page.current_path).to eq(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: package))
    end
  end
end
