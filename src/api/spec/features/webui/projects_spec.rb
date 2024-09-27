require 'browser_helper'

RSpec.describe 'Projects', :js, :vcr do
  let!(:admin_user) { create(:admin_user, :with_home) }
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let(:broken_package_with_error) { create(:package, project: project, name: 'broken_package') }

  it 'project show' do
    project.update(description: 'Original description')

    login user
    visit project_show_path(project: project)
    expect(page).to have_text(/Packages .*0/)
    expect(page).to have_text('This project does not contain any package')
    expect(page).to have_text(project.description)
    expect(page).to have_css('h3', text: project.title)
  end

  describe 'changing project title and description' do
    context 'when accepting the changes' do
      it 'updates the project title, description and url' do
        Flipper.enable(:foster_collaboration)
        login user
        visit project_show_path(project: project)

        click_link('Edit')
        expect(page).to have_text("Edit Project #{project}")

        fill_in 'project_title', with: 'My Title "hopefully" got changed'
        fill_in 'project_description', with: 'New description. No kidding.. Brand new!'
        fill_in 'project_url', with: 'https://test.url'
        fill_in('project_report_bug_url', with: 'https://test-report-bug.url')
        click_button 'Update'
        wait_for_ajax

        expect(find_by_id('project-title')).to have_text('My Title "hopefully" got changed')
        expect(find_by_id('description-text')).to have_text('New description. No kidding.. Brand new!')
        expect(page).to have_text('https://test.url')
        click_link('Actions') if mobile?
        expect(page).to have_link('Report Bug', href: 'https://test-report-bug.url')
      end
    end

    context 'when cancelling the changes' do
      before do
        project.update(title: 'Original title', description: 'Original description')
      end

      it "renders back the original project's details" do
        login user
        visit project_show_path(project: project)

        click_link('Edit')
        expect(page).to have_text("Edit Project #{project}")

        fill_in 'project_title', with: 'My Title "hopefully" got changed'
        fill_in 'project_description', with: 'New description. No kidding.. Brand new!'
        click_link 'Cancel'
        wait_for_ajax

        expect(page).to have_text(project.title)
        expect(page).to have_text(project.description)
      end
    end
  end

  describe 'subprojects' do
    it 'create a subproject' do
      login user
      visit project_show_path(user.home_project)
      click_link('Subprojects')

      expect(page).to have_text('This project has no subprojects')
      desktop? ? click_link('Create Subproject') : click_menu_link('Actions', 'Create Subproject')
      fill_in 'project_name', with: 'coolstuff'
      click_button('Accept')
      expect(page).to have_content("Project '#{user.home_project_name}:coolstuff' was created successfully")

      expect(page).to have_current_path(project_show_path(project: "#{user.home_project_name}:coolstuff"))
      expect(find_by_id('project-title').text).to start_with("#{user.home_project_name}:coolstuff")
    end
  end

  describe 'locked projects' do
    let!(:locked_project) { create(:locked_project, name: 'locked_project') }
    let!(:relationship) { create(:relationship, project: locked_project, user: user) }

    before do
      login user
      visit project_show_path(project: locked_project.name)
    end

    it 'unlock' do
      desktop? ? click_link('Unlock Project') : click_menu_link('Actions', 'Unlock Project')
      fill_in 'comment', with: 'Freedom at last!'
      click_button('Accept')
      expect(page).to have_content('Successfully unlocked project')

      visit project_show_path(project: locked_project.name)
      expect(page).to have_no_text('is locked')
    end

    it 'fail to unlock' do
      allow_any_instance_of(Project).to receive(:can_be_unlocked?).and_return(false)

      desktop? ? click_link('Unlock Project') : click_menu_link('Actions', 'Unlock Project')
      fill_in 'comment', with: 'Freedom at last!'
      click_button('Accept')
      expect(page).to have_content("Project can't be unlocked")

      visit project_show_path(project: locked_project.name)
      expect(page).to have_text('is locked')
    end
  end

  describe 'branching' do
    let(:other_user) { create(:confirmed_user, :with_home, login: 'other_user') }
    let!(:package_of_another_project) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }

    before do
      login user
      visit project_show_path(project)
      click_link('Branch Package')
    end

    it 'an existing package' do
      fill_in('linked_project', with: other_user.home_project_name)
      # Remove focus from autocomplete. Needed to remove the `disabled` attribute from `linked_package`.
      find_by_id('target_package').click
      fill_in('linked_package', with: package_of_another_project.name)
      # This needs global write through
      click_button('Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path('/package/show/home:Jane/branch_test_package')
    end

    it 'an existing package, but chose a different target package name' do
      fill_in('linked_project', with: other_user.home_project_name)
      # Remove focus from autocomplete. Needed to remove the `disabled` attribute from `linked_package`.
      find_by_id('target_package').click
      fill_in('linked_package', with: package_of_another_project.name)
      fill_in('Branch package name', with: 'some_different_name')
      # This needs global write through
      click_button('Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path("/package/show/#{user.home_project_name}/some_different_name", ignore_query: true)
    end

    it 'an existing package were the target package already exists' do
      create(:package_with_file, name: package_of_another_project.name, project: user.home_project)

      fill_in('linked_project', with: other_user.home_project_name)
      # Remove focus from autocomplete. Needed to remove the `disabled` attribute from `linked_package`.
      find_by_id('target_package').click
      fill_in('linked_package', with: package_of_another_project.name)
      # This needs global write through
      click_button('Branch')

      expect(page).to have_text('You have already branched this package')
      expect(page).to have_current_path('/package/show/home:Jane/branch_test_package')
    end
  end

  describe 'maintenance projects' do
    it 'creating a maintenance project' do
      login(admin_user)
      visit project_show_path(project)

      click_link('Attributes')
      click_link('Add Attribute')
      select('OBS:MaintenanceProject')
      click_button('Add')

      expect(page).to have_text('Attribute was successfully created.')
      expect(find('table tr td:first-child')).to have_text('OBS:MaintenanceProject')
    end
  end

  describe 'maintenance incidents' do
    let(:maintenance_project) { create(:maintenance_project, name: "#{project.name}:maintenance_project") }
    let(:target_repository) { create(:repository, name: 'theone') }

    it 'visiting the maintenance overview' do
      login user

      visit project_show_path(maintenance_project)
      click_link('Incidents')
      page.execute_script('window.scrollBy(0,50)')
      # The next click fires a step that might take longer than expected
      # therefore the test after that has a `wait` parameter with a sufficient amount of time to wait for it
      click_link('Create Maintenance Incident')
      expect(page).to have_css('#project-title', text: "#{maintenance_project}:0", wait: 12)

      # We can not create this via the Bootstrap UI, except by adding plain XML to the meta editor
      repository = create(:repository, project: Project.find_by(name: "#{project.name}:maintenance_project:0"), name: 'target')
      create(:release_target, repository: repository, target_repository: target_repository, trigger: 'maintenance')

      visit project_show_path(maintenance_project)
      click_link('Incidents')

      within('#incident-table') do
        maintenance_project.maintenance_incidents.each do |incident|
          expect(page).to have_link("0: #{incident.name}", href: project_show_path(incident.name))
        end
      end
    end
  end
end
