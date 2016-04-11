require "browser_helper"

RSpec.feature "Projects", :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user, login: "Jane") }
  let(:project) { Project.find_by_name(user.home_project_name) }

  it_behaves_like 'user tab' do
    let(:project_path) { project_show_path(project: user_tab_user.home_project_name) }
    let(:project) { Project.find_by_name(user_tab_user.home_project_name) }
  end

  scenario "project show" do
    login user
    visit project_show_path(project: project)
    expect(page).to have_text("Packages (0)")
    expect(page).to have_text("This project does not contain any packages")
    expect(page).to have_text(project.description)
    expect(page).to have_css("h3", text: project.title)
  end

  scenario "changing project title and description" do
    login user
    visit project_show_path(project: project)

    click_link("Edit description")
    expect(page).to have_text("Edit Project Information of")

    fill_in "project_title", with: "My Title hopefully got changed"
    fill_in "project_description", with: "New description. Not kidding.. Brand new!"
    click_button "Update Project"

    visit project_show_path(project: project)
    expect(find(:id, "project_title")).to have_text("My Title hopefully got changed")
    expect(find(:id, "description-text")).to have_text("New description. Not kidding.. Brand new!")
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

  describe "locked projects" do
    let!(:locked_project) { create(:locked_project, name: "locked_project") }
    let!(:relationship) { create(:relationship, project: locked_project, user: user) }

    before do
      login user
      visit project_show_path(project: locked_project.name)
    end

    scenario "unlock project" do
      click_link("Unlock project")
      fill_in "comment", with: "Freedom at last!"
      click_button("Ok")
      expect(page).to have_text("Successfully unlocked project")

      visit project_show_path(project: locked_project.name)
      expect(page).not_to have_text("is locked")
    end

    scenario "unlock project" do
      Project.any_instance.stubs(:can_be_unlocked?).returns(false)

      click_link("Unlock project")
      fill_in "comment", with: "Freedom at last!"
      click_button("Ok")
      expect(page).to have_text("Project can't be unlocked")

      visit project_show_path(project: locked_project.name)
      expect(page).to have_text("is locked")
    end
  end
end
