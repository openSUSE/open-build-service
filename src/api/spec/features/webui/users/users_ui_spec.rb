require "browser_helper"

RSpec.feature "User's UI shows", type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'moi') }
  let(:another_user) { create(:confirmed_user, login: 'henne') }
  let(:project) { create(:project, name: 'project_a') }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  before do
    login user
  end

  scenario "a table with involved packages" do
    create(:relationship_package_user, package: project_with_package.packages.first, user: another_user)
    visit user_show_path(user: another_user)

    within "table#ipackages_wrapper_table" do
      expect(find(:xpath, './/tr[1]/td[1]').text).to eq(project_with_package.packages.first.name)
      expect(find(:xpath, './/tr[1]/td[2]').text).to eq(project_with_package.name)
    end
  end

  scenario "a table with involved projects" do
    create(:relationship_project_user, project: project, user: another_user)
    create(:relationship_project_user, project: project_with_package, user: another_user)
    visit user_show_path(user: another_user)

    click_link("Involved Projects")
    within "table#projects_table" do
      expect(find(:xpath, './/tr[1]/td[1]').text).to eq(another_user.home_project_name)
      expect(find(:xpath, './/tr[2]/td[1]').text).to eq(project.name)
      expect(find(:xpath, './/tr[2]/td[2]').text).to eq(project.title)
      expect(find(:xpath, './/tr[3]/td[1]').text).to eq(project_with_package.name)
      expect(find(:xpath, './/tr[3]/td[2]').text).to eq(project_with_package.title)
    end
  end

  scenario "a table with owned projects and packages" do
    create(:attrib, attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: project_with_package)
    create(:relationship_package_user, package: project_with_package.packages.first, user: another_user)
    create(:relationship_project_user, project: project_with_package, user: another_user)
    visit user_show_path(user: another_user)

    click_link("Owned Project/Packages")
    within "table#iowned_wrapper_table" do
      expect(find(:xpath, './/tr[1]/td[2]').text).to eq(project_with_package.name)
      expect(find(:xpath, './/tr[2]/td[1]').text).to eq(project_with_package.packages.first.name)
      expect(find(:xpath, './/tr[2]/td[2]').text).to eq(project_with_package.name)
    end
  end

  scenario "png icons" do
    visit "/user/icon/#{user.login}.png"
    expect(page.status_code).to be 200
    visit "/user/icon/#{user.login}.png?size=20"
    expect(page.status_code).to be 200
    visit "/user/show/#{user.login}"
    expect(page.status_code).to be 200
    visit "/user/show/#{user.login}?size=20"
    expect(page.status_code).to be 200
  end
end
