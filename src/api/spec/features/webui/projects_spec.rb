require 'browser_helper'

RSpec.feature 'Projects', type: :feature, js: true do
  let!(:admin_user) { create(:admin_user) }
  let!(:user) { create(:confirmed_user, login: 'Jane') }
  let(:project) { user.home_project }

  it_behaves_like 'user tab' do
    let(:project_path) { project_show_path(user_tab_user.home_project) }
    let(:project) { user_tab_user.home_project }
  end

  scenario 'project show' do
    login user
    visit project_show_path(project: project)
    expect(page).to have_text('Packages (0)')
    expect(page).to have_text('This project does not contain any packages')
    expect(page).to have_text(project.description)
    expect(page).to have_css('h3', text: project.title)
  end

  scenario 'changing project title and description' do
    login user
    visit project_show_path(project: project)

    click_link('Edit description')
    expect(page).to have_text('Edit Project Information of')

    fill_in 'project_title', with: 'My Title hopefully got changed'
    fill_in 'project_description', with: 'New description. Not kidding.. Brand new!'
    click_button 'Update Project'

    visit project_show_path(project: project)
    expect(find(:id, 'project_title')).to have_text('My Title hopefully got changed')
    expect(find(:id, 'description-text')).to have_text('New description. Not kidding.. Brand new!')
  end

  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraphs(250) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create package')
      expect(page).to have_text("Create New Package for #{user.home_project_name}")
    end

    scenario 'with valid data' do
      fill_in 'name', with: 'coolstuff'
      fill_in 'title', with: 'cool stuff everyone needs'
      fill_in 'description', with: very_long_description
      click_button 'Save changes'

      expect(page).to have_text("Package 'coolstuff' was created successfully")
      expect(page.current_path).to eq(package_show_path(project: user.home_project_name, package: 'coolstuff'))
      expect(find(:css, 'h3#package_title')).to have_text('cool stuff everyone needs')
      expect(find(:css, 'pre#description-text')).to have_text(very_long_description)
    end

    scenario 'with invalid data (validation fails)' do
      fill_in 'name', with: 'cool stuff'
      click_button 'Save changes'

      expect(page).to have_text("Invalid package name: 'cool stuff'")
      expect(page.current_path).to eq("/project/new_package/#{user.home_project_name}")
    end

    scenario 'that already exists' do
      create(:package, name: 'coolstuff', project: user.home_project)

      fill_in 'name', with: 'coolstuff'
      click_button 'Save changes'

      expect(page).to have_text("Package 'coolstuff' already exists in project '#{user.home_project_name}'")
      expect(page.current_path).to eq("/project/new_package/#{user.home_project_name}")
    end
  end

  describe 'creating packages in projects not owned by user, eg. global namespace' do
    let(:other_user) { create(:confirmed_user, login: 'other_user') }
    let(:global_project) { create(:project, name: 'global_project') }

    scenario 'as non-admin user' do
      login other_user
      visit project_show_path(project: global_project)
      expect(page).not_to have_link('Create package')

      # Use direct path instead
      visit "/project/new_package/#{global_project}"

      fill_in 'name', with: 'coolstuff'
      click_button 'Save changes'

      expect(page).to have_text("You can't create packages in #{global_project}")
      expect(page.current_path).to eq("/project/new_package/#{global_project}")
    end

    scenario 'as admin' do
      login admin_user
      visit project_show_path(project: global_project)
      click_link('Create package')

      fill_in 'name', with: 'coolstuff'
      click_button 'Save changes'

      expect(page).to have_text("Package 'coolstuff' was created successfully")
      expect(page.current_path).to eq(package_show_path(project: global_project.to_s, package: 'coolstuff'))
    end
  end

  describe 'subprojects' do
    scenario 'create a subproject' do
      login user
      visit project_show_path(user.home_project)
      click_link('Subprojects')

      expect(page).to have_text('This project has no subprojects')
      click_link('create_subproject_link')
      fill_in 'project_name', with: 'coolstuff'
      click_button 'Create Project'
      expect(page).to have_content("Project '#{user.home_project_name}:coolstuff' was created successfully")

      expect(page.current_path).to match(project_show_path(project: "#{user.home_project_name}:coolstuff"))
      expect(find('#project_title').text).to eq("#{user.home_project_name}:coolstuff")
    end

    scenario "create subproject with checked 'disable publishing' checkbox" do
      login user
      visit project_subprojects_path(project: user.home_project)

      click_link('create_subproject_link')
      fill_in 'project_name', with: 'coolstuff'
      check('disable_publishing')
      click_button('Create Project')
      click_link('Repositories')

      expect(page).to have_selector('.current_flag_state.icons-publish_disable_blue')
      subproject = Project.find_by(name: "#{user.home_project_name}:coolstuff")
      expect(subproject.flags.where(flag: 'publish', status: 'disable')).to exist
    end
  end

  describe 'locked projects' do
    let!(:locked_project) { create(:locked_project, name: 'locked_project') }
    let!(:relationship) { create(:relationship, project: locked_project, user: user) }

    before do
      login user
      visit project_show_path(project: locked_project.name)
    end

    scenario 'unlock project' do
      click_link('Unlock project')
      fill_in 'comment', with: 'Freedom at last!'
      click_button('Ok')
      expect(page).to have_text('Successfully unlocked project')

      visit project_show_path(project: locked_project.name)
      expect(page).not_to have_text('is locked')
    end

    scenario 'unlock project' do
      allow_any_instance_of(Project).to receive(:can_be_unlocked?).and_return(false)

      click_link('Unlock project')
      fill_in 'comment', with: 'Freedom at last!'
      click_button('Ok')
      expect(page).to have_text("Project can't be unlocked")

      visit project_show_path(project: locked_project.name)
      expect(page).to have_text('is locked')
    end
  end

  describe 'repositories tab' do
    include_examples 'tests for sections with flag tables'

    describe 'DoD repositories' do
      let(:project_with_dod_repo) { create(:project) }
      let(:repository) { create(:repository, project: project_with_dod_repo) }
      let!(:download_repository) { create(:download_repository, repository: repository) }

      before do
        login admin_user
      end

      scenario 'adding DoD repositories' do
        visit(project_repositories_path(project: admin_user.home_project_name))
        click_link('Add DoD repository')
        fill_in('Repository name', with: 'My DoD repository')
        select('i586', from: 'Architecture')
        select('rpmmd', from: 'Type')
        fill_in('Url', with: 'http://somerandomurl.es')
        fill_in('Arch. Filter', with: 'i586, noarch')
        fill_in('Master Url', with: 'http://somerandomurl2.es')
        fill_in('SSL Fingerprint', with: '293470239742093')
        fill_in('Public Key', with: 'JLKSDJFSJ83U4902RKLJSDFLJF2J9IJ23OJFKJFSDF')
        click_button('Save')

        within '.repository-container' do
          expect(page).to have_text('My DoD repository')
          expect(page).to have_link('Delete repository')
          expect(page).to have_text('Download on demand sources')
          expect(page).to have_link('Add')
          expect(page).to have_link('Edit')
          expect(page).to have_link('Delete')
          expect(page).to have_link('http://somerandomurl.es')
          expect(page).to have_text('rpmmd')
        end
      end

      scenario 'removing DoD repositories' do
        visit(project_repositories_path(project: project_with_dod_repo))
        within '.repository-container' do
          click_link('Delete repository')
        end
        expect(project_with_dod_repo.repositories).to be_empty
      end

      # Note DownloadRepositories belong to Repositories (= DoD repositories)
      scenario 'editing download repositories' do
        visit(project_repositories_path(project: project_with_dod_repo))
        within '.repository-container' do
          click_link('Edit')
        end
        select('i586', from: 'Architecture')
        select('deb', from: 'Type')
        fill_in('Url', with: 'http://some_random_url_2.es')
        fill_in('Arch. Filter', with: 'i586, noarch')
        fill_in('Master Url', with: 'http://some_other_url.es')
        fill_in('SSL Fingerprint', with: 'test')
        fill_in('Public Key', with: 'some_key')
        click_button('Update Download on Demand')

        download_repository.reload
        expect(download_repository.arch).to eq 'i586'
        expect(download_repository.repotype).to eq 'deb'
        expect(download_repository.url).to eq 'http://some_random_url_2.es'
        expect(download_repository.archfilter).to eq 'i586, noarch'
        expect(download_repository.masterurl).to eq 'http://some_other_url.es'
        expect(download_repository.mastersslfingerprint).to eq 'test'
        expect(download_repository.pubkey).to eq 'some_key'
      end

      scenario 'removing download repositories' do
        create(:repository_architecture, repository: repository, architecture: Architecture.find_by_name('i586'))
        download_repository_2 = create(:download_repository, repository: repository, arch: 'i586')

        visit(project_repositories_path(project: project_with_dod_repo))
        # Delete link
        find(:xpath, "//a[@href='/download_repositories/#{download_repository.id}?project=#{project_with_dod_repo}'][text()='Delete']").click
        expect(page).to have_text 'Successfully removed Download on Demand'
        expect(repository.download_repositories.count).to eq 1

        find(:xpath, "//a[@href='/download_repositories/#{download_repository_2.id}?project=#{project_with_dod_repo}'][text()='Delete']").click
        expect(page).to have_text "Download on Demand can't be removed: DoD Repositories must have at least one repository."
        expect(repository.download_repositories.count).to eq 1
      end

      scenario 'adding DoD repositories via meta editor' do
        fixture_file = File.read(Rails.root + 'test/fixtures/backend/download_on_demand/project_with_dod.xml').
                       gsub('user5', admin_user.login)

        visit(project_meta_path(project: admin_user.home_project_name))
        page.evaluate_script("editors[0].setValue(\"#{fixture_file.gsub("\n", '\n')}\");")
        click_button('Save')
        expect(page).to have_css('#flash-messages', text: 'Config successfully saved!')

        visit(project_repositories_path(project: admin_user.home_project_name))
        within '.repository-container' do
          expect(page).to have_link('standard')
          expect(page).to have_link('Delete repository')
          expect(page).to have_text('Download on demand sources')
          expect(page).to have_link('Add')
          expect(page).to have_link('Edit')
          expect(page).to have_link('Delete')
          expect(page).to have_link('http://mola.org2')
          expect(page).to have_text('rpmmd')
        end
      end
    end
  end

  describe 'branching' do
    let(:other_user) { create(:confirmed_user, login: 'other_user') }
    let!(:package_of_another_project) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }

    before do
      if CONFIG['global_write_through']
        Backend::Connection.put("/source/#{CGI.escape(project.name)}/_meta", project.to_axml)
      end
      login user
      visit project_show_path(project)
      click_link('Branch existing package')
    end

    after do
      if CONFIG['global_write_through']
        Backend::Connection.delete("/source/#{CGI.escape(other_user.home_project_name)}")
        Backend::Connection.delete("/source/#{CGI.escape(user.home_project_name)}")
      end
    end

    scenario 'an existing package' do
      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq('/package/show/home:Jane/branch_test_package')
    end

    scenario 'an existing package, but chose a different target package name' do
      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      fill_in('New package name:', with: 'some_different_name')
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq("/package/show/#{user.home_project_name}/some_different_name")
    end

    scenario 'an existing package to an invalid target package or project' do
      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      fill_in('New package name:', with: 'something/illegal')
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Failed to branch: Validation failed: Name is illegal')
      expect(page.current_path).to eq('/project/new_package_branch/home:Jane')
    end

    scenario 'an existing package were the target package already exists' do
      create(:package_with_file, name: package_of_another_project.name, project: user.home_project)

      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('You have already branched this package')
      expect(page.current_path).to eq('/package/show/home:Jane/branch_test_package')
    end

    scenario 'a non-existing package' do
      fill_in('Name of original project:', with: 'non-existing_package')
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page.current_path).to eq('/project/new_package_branch/home:Jane')
    end

    scenario 'a package with disabled access flag' do
      create(:access_flag, status: 'disable', project: other_user.home_project)

      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      fill_in('New package name:', with: 'some_different_name')
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page.current_path).to eq('/project/new_package_branch/home:Jane')
    end

    scenario 'a package with disabled sourceaccess flag' do
      create(:sourceaccess_flag, status: 'disable', project: other_user.home_project)

      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)
      fill_in('New package name:', with: 'some_different_name')
      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Sorry, you are not authorized to branch this Package.')
      expect(page.current_path).to eq('/project/new_package_branch/home:Jane')
    end

    scenario 'a package and select current revision' do
      fill_in('Name of original project:', with: other_user.home_project_name)
      fill_in('Name of package in original project:', with: package_of_another_project.name)

      find("input[id='current_revision']").set(true)

      # This needs global write through
      click_button('Create Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq('/package/show/home:Jane/branch_test_package')

      visit package_show_path('home:Jane', 'branch_test_package', expand: 0)
      click_link('_link')

      expect(page).to have_xpath(".//span[@class='cm-attribute' and text()='rev']")
    end
  end

  describe 'maintenance projects' do
    scenario 'creating a maintenance project' do
      login(admin_user)
      visit project_show_path(project)

      click_link('Advanced')
      click_link('Attributes')
      click_link('Add a new attribute')
      select('OBS:MaintenanceProject')
      click_button('Create Attribute')

      expect(page).to have_text('Attribute was successfully created.')
      expect(find('table tr.attribute-values td:first-child')).to have_text('OBS:MaintenanceProject')
    end
  end

  describe 'maintained projects' do
    let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project') }

    scenario 'creating a maintened project' do
      login(admin_user)
      visit project_show_path(maintenance_project)

      click_link('Maintained Projects')
      click_link('Add project to maintenance')
      fill_in('Project to maintain:', with: project.name)
      click_button('Ok')

      expect(page).to have_text("Added #{project.name} to maintenance")
      expect(find('table#maintained_projects_table td:first-child')).to have_text(project.name)
    end
  end

  describe 'monitor' do
    let!(:project) { create(:project, name: 'TestProject') }
    let!(:package1) { create(:package, project: project, name: 'TestPackage') }
    let!(:package2) { create(:package, project: project, name: 'SecondPackage') }
    let!(:repository1) { create(:repository, project: project, name: 'openSUSE_Tumbleweed', architectures: ['x86_64', 'i586']) }
    let!(:repository2) { create(:repository, project: project, name: 'openSUSE_Leap_42.3', architectures: ['x86_64', 'i586']) }
    let!(:repository3) { create(:repository, project: project, name: 'openSUSE_Leap_42.2', architectures: ['x86_64', 'i586']) }

    let(:build_results_xml) do
      <<-XML
      <resultlist state="dc66a487ea4d97b4f157d075a0e747b9">
        <result project="TestProject" repository="openSUSE_Tumbleweed" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.3" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.2" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Tumbleweed" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.3" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.2" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
      </resultlist>
      XML
    end

    let(:build_result) { Buildresult.new(build_results_xml) }

    before do
      login admin_user
      allow(Buildresult).to receive(:find).and_return(build_result)
      visit project_monitor_path(project.name)
      expect(page).to have_text('Monitor')
    end

    scenario 'filtering build results by package name' do
      fill_in 'pkgname', with: package1.name
      click_button 'Filter:'

      build_status_table = find('table.buildstatus')
      expect(build_status_table).to have_text(package1.name)
      expect(build_status_table).not_to have_text(package2.name)
    end

    scenario 'filtering build results by architecture' do
      find('#archlink').click
      uncheck 'arch_x86_64'
      click_button 'Filter:'

      build_status_table = find('table.buildstatus')
      expect(build_status_table).to have_text('i586')
      expect(build_status_table).not_to have_text('x86_64')
    end

    scenario 'filtering build results by repository' do
      find('#repolink').click
      uncheck 'repo_openSUSE_Leap_42_2'
      uncheck 'repo_openSUSE_Leap_42_3'
      click_button 'Filter:'

      build_status_table = find('table.buildstatus')
      expect(build_status_table).not_to have_text('openSUSE_Leap_42.2')
      expect(build_status_table).not_to have_text('openSUSE_Leap_42.3')
      expect(build_status_table).to have_text('openSUSE_Tumbleweed')
    end

    scenario 'filtering build results by last build' do
      check 'lastbuild'
      click_button 'Filter:'

      build_status_table = find('table.buildstatus')
      expect(build_status_table).to have_text('openSUSE_Leap_42.2')
      expect(build_status_table).to have_text('openSUSE_Leap_42.3')
      expect(build_status_table).to have_text('openSUSE_Tumbleweed')
      expect(build_status_table).to have_text('i586')
      expect(build_status_table).to have_text('x86_64')
      expect(build_status_table).to have_text(package1.name)
      expect(build_status_table).to have_text(package2.name)
    end
  end
end
