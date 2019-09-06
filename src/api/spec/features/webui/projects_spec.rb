require 'browser_helper'

RSpec.feature 'Projects', type: :feature, js: true do
  let!(:admin_user) { create(:admin_user, :with_home) }
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }

  scenario 'project show' do
    login user
    visit project_show_path(project: project)
    expect(page).to have_text(/Packages .*0/)
    expect(page).to have_text('This project does not contain any packages')
    expect(page).to have_text(project.description)
    expect(page).to have_css('h3', text: project.title)
  end

  scenario 'changing project title and description' do
    login user
    visit project_show_path(project: project)

    click_on('Edit Project')
    expect(page).to have_text("Edit Project #{project}")

    fill_in 'project_title', with: 'My Title hopefully got changed'
    fill_in 'project_description', with: 'New description. Not kidding.. Brand new!'
    click_button 'Update'

    visit project_show_path(project: project)
    expect(find(:id, 'project-title')).to have_text('My Title hopefully got changed')
    expect(find(:id, 'description-text')).to have_text('New description. Not kidding.. Brand new!')
  end

  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraph(sentence_count: 20) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create Package')
      expect(page).to have_text("Create Package for #{user.home_project_name}")
    end

    scenario 'with invalid data (validation fails)' do
      fill_in 'name', with: 'cool stuff'
      click_button('Create')

      expect(page).to have_text("Invalid package name: 'cool stuff'")
      expect(page.current_path).to eq("/project/new_package/#{user.home_project_name}")
    end

    scenario 'that already exists' do
      create(:package, name: 'coolstuff', project: user.home_project)

      fill_in 'name', with: 'coolstuff'
      click_button('Create')

      expect(page).to have_text("Package 'coolstuff' already exists in project '#{user.home_project_name}'")
      expect(page.current_path).to eq("/project/new_package/#{user.home_project_name}")
    end

    scenario 'with valid data' do
      fill_in 'name', with: 'coolstuff'
      fill_in 'title', with: 'cool stuff everyone needs'
      fill_in 'description', with: very_long_description
      click_button 'Create'

      expect(page).to have_text("Package 'coolstuff' was created successfully")
      expect(page).to have_current_path(package_show_path(project: user.home_project_name, package: 'coolstuff'))
      expect(find(:css, '#package-title')).to have_text('cool stuff everyone needs')
      expect(find(:css, '#description-text')).to have_text(very_long_description)
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

      expect(page).to have_text('Sorry, you are not authorized to update this Project')
      expect(page.current_path).to eq(root_path)
    end

    scenario 'as admin' do
      login admin_user
      visit project_show_path(project: global_project)
      click_link('Create Package')

      fill_in 'name', with: 'coolstuff'
      click_button('Create')

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
      click_link('Add New Subproject')
      fill_in 'project_name', with: 'coolstuff'
      click_button('Accept')
      expect(page).to have_content("Project '#{user.home_project_name}:coolstuff' was created successfully")

      expect(page.current_path).to match(project_show_path(project: "#{user.home_project_name}:coolstuff"))
      expect(find('#project-title').text).to eq("#{user.home_project_name}:coolstuff")
    end
  end

  describe 'locked projects' do
    let!(:locked_project) { create(:locked_project, name: 'locked_project') }
    let!(:relationship) { create(:relationship, project: locked_project, user: user) }

    before do
      login user
      visit project_show_path(project: locked_project.name)
    end

    scenario 'unlock' do
      click_link('Unlock Project')
      fill_in 'comment', with: 'Freedom at last!'
      click_button('Accept')
      expect(page).to have_content('Successfully unlocked project')

      visit project_show_path(project: locked_project.name)
      expect(page).not_to have_text('is locked')
    end

    scenario 'fail to unlock' do
      allow_any_instance_of(Project).to receive(:can_be_unlocked?).and_return(false)

      click_link('Unlock Project')
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
      click_link('Branch Existing Package')
    end

    scenario 'an existing package' do
      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq('/package/show/home:Jane/branch_test_package')
    end

    scenario 'an existing package, but chose a different target package name' do
      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      fill_in('Branch package name', with: 'some_different_name')
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq("/package/show/#{user.home_project_name}/some_different_name")
    end

    scenario 'an existing package were the target package already exists' do
      create(:package_with_file, name: package_of_another_project.name, project: user.home_project)

      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('You have already branched this package')
      expect(page.current_path).to eq('/package/show/home:Jane/branch_test_package')
    end

    scenario 'a non-existing package' do
      fill_in('linked_project', with: 'non-existing_package')
      fill_in('linked_package', with: package_of_another_project.name)

      click_button('Accept')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page).to have_current_path(project_show_path('home:Jane'))
    end
  end

  describe 'maintenance projects' do
    scenario 'creating a maintenance project' do
      login(admin_user)
      visit project_show_path(project)

      click_link('Attributes')
      click_link('Add a new attribute')
      select('OBS:MaintenanceProject')
      click_button('Add')

      expect(page).to have_text('Attribute was successfully created.')
      expect(find('table tr td:first-child')).to have_text('OBS:MaintenanceProject')
    end
  end

  describe 'maintenance incidents' do
    let(:maintenance_project) { create(:maintenance_project, name: "#{project.name}:maintenance_project") }
    let(:target_repository) { create(:repository, name: 'theone') }

    scenario 'visiting the maintenance overview' do
      login user

      visit project_show_path(maintenance_project)
      click_link('Incidents')
      click_link('Create Maintenance Incident')
      expect(page).to have_css('#flash', text: "Created maintenance incident project #{project.name}:maintenance_project:0")

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
