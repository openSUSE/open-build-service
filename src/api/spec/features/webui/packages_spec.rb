require "browser_helper"

RSpec.feature "Packages", :type => :feature, :js => true do
  it_behaves_like 'user tab' do
    let(:package) {
      create(:package, name: "group_test_package",
        project_id: Project.find_by(name: group_tab_user.home_project_name).id)
    }
    let(:project_path) { package_show_path(project: group_tab_user.home_project_name, package: package) }
  end
end
