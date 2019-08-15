require 'browser_helper'

RSpec.feature 'Bootstrap_Projects', type: :feature, js: true, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let!(:admin_user) { create(:admin_user) }
  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraph(sentence_count: 20) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create Package')
    end

    scenario 'with valid data' do
      expect(page).to have_text("Create Package for #{user.home_project_name}")

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

  describe 'branching' do
    let(:other_user) { create(:confirmed_user, :with_home, login: 'other_user') }
    let!(:package_of_another_project) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }

    before do
      login user
      visit project_show_path(project)
      click_link('Branch Existing Package')
    end

    scenario 'a non-existing package' do
      fill_in('linked_project', with: 'non-existing_package')
      fill_in('linked_package', with: package_of_another_project.name)

      click_button('Accept')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page).to have_current_path(project_show_path('home:Jane'))
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
