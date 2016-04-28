require "browser_helper"

RSpec.feature "Projects", :type => :feature, :js => true do
  let!(:admin_user) { create(:admin_user) }
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

  describe "DoD repositories" do
    let(:project_with_dod_repo) { create(:project) }
    let(:repository) { create(:repository, project: project_with_dod_repo) }
    let!(:download_repository) { create(:download_repository, repository: repository) }

    before do
      login admin_user
    end

    scenario "adding DoD repositories" do
      visit(project_repositories_path(project: admin_user.home_project_name))
      click_link("Add DoD repository")
      fill_in("Repository name", with: "My DoD repository")
      select("i586", from: "Architecture")
      select("rpmmd", from: "Type")
      fill_in("Url", with: "http://somerandomurl.es")
      fill_in("Arch. Filter", with: "i586, noarch")
      fill_in("Master Url", with: "http://somerandomurl2.es")
      fill_in("SSL Fingerprint", with: "293470239742093")
      fill_in("Public Key", with: "JLKSDJFSJ83U4902RKLJSDFLJF2J9IJ23OJFKJFSDF")
      click_button("Save")

      within ".repository-container" do
        expect(page).to have_text("My DoD repository")
        expect(page).to have_link("Delete repository")
        expect(page).to have_text("Download on demand sources")
        expect(page).to have_link("Add")
        expect(page).to have_link("Edit")
        expect(page).to have_link("Delete")
        expect(page).to have_link("http://somerandomurl.es")
        expect(page).to have_text("rpmmd")
      end
    end

    scenario "removing DoD repositories" do
      visit(project_repositories_path(project: project_with_dod_repo))
      within ".repository-container" do
        click_link("Delete repository")
      end
      expect(project_with_dod_repo.repositories).to be_empty
    end

    # Note DownloadRepositories belong to Repositories (= DoD repositories)
    scenario "editing download repositories" do
      visit(project_repositories_path(project: project_with_dod_repo))
      within ".repository-container" do
        click_link("Edit")
      end
      select("i586", from: "Architecture")
      select("deb", from: "Type")
      fill_in("Url", with: "http://some_random_url_2.es")
      fill_in("Arch. Filter", with: "i586, noarch")
      fill_in("Master Url", with: "http://some_other_url.es")
      fill_in("SSL Fingerprint", with: "test")
      fill_in("Public Key", with: "some_key")
      click_button("Update Download on Demand")

      download_repository.reload
      expect(download_repository.arch).to eq "i586"
      expect(download_repository.repotype).to eq "deb"
      expect(download_repository.url).to eq "http://some_random_url_2.es"
      expect(download_repository.archfilter).to eq "i586, noarch"
      expect(download_repository.masterurl).to eq "http://some_other_url.es"
      expect(download_repository.mastersslfingerprint).to eq "test"
      expect(download_repository.pubkey).to eq "some_key"
    end

    scenario "removing download repositories" do
      create(:repository_architecture, repository: repository, architecture: Architecture.find_by_name("i586"))
      download_repository_2 = create(:download_repository, repository: repository, arch: "i586")

      visit(project_repositories_path(project: project_with_dod_repo))
      # Delete link
      find(:xpath, "//a[@href='/download_repositories/#{download_repository.id}?project=#{project_with_dod_repo}'][text()='Delete']").click
      expect(page).to have_text "Successfully removed Download on Demand"
      expect(repository.download_repositories.count).to eq 1

      find(:xpath, "//a[@href='/download_repositories/#{download_repository_2.id}?project=#{project_with_dod_repo}'][text()='Delete']").click
      expect(page).to have_text "Download on Demand can't be removed: DoD Repositories must have at least one repository."
      expect(repository.download_repositories.count).to eq 1
    end

    scenario "adding DoD repositories via meta editor" do
      fixture_file = File.read(Rails.root + "test/fixtures/backend/download_on_demand/project_with_dod.xml").
        gsub("user5", admin_user.login)

      visit(project_meta_path(project: admin_user.home_project_name))
      page.evaluate_script("editors[0].setValue(\"#{fixture_file.gsub("\n", '\n')}\");")
      click_button("Save")
      expect(page).to have_css("#flash-messages", text: "Config successfully saved!")

      visit(project_repositories_path(project: admin_user.home_project_name))
      within ".repository-container" do
        expect(page).to have_link("standard")
        expect(page).to have_link("Delete repository")
        expect(page).to have_text("Download on demand sources")
        expect(page).to have_link("Add")
        expect(page).to have_link("Edit")
        expect(page).to have_link("Delete")
        expect(page).to have_link("http://mola.org2")
        expect(page).to have_text("rpmmd")
      end
    end
  end
end
