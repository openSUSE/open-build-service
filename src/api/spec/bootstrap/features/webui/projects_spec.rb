require 'browser_helper'

RSpec.feature 'Bootstrap_Projects', type: :feature, js: true, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'Jane') }
  let(:project) { user.home_project }
  let!(:admin_user) { create(:admin_user) }
  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraph(20) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create Package')
    end

    scenario 'with valid data' do
      expect(page).to have_text("Create New Package for #{user.home_project_name}")

      fill_in 'name', with: 'coolstuff'
      fill_in 'title', with: 'cool stuff everyone needs'
      fill_in 'description', with: very_long_description
      click_button 'Accept'

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
    expect(page).to have_text('Edit Project')

    fill_in 'project_title', with: 'My Title hopefully got changed'
    fill_in 'project_description', with: 'New description. Not kidding.. Brand new!'
    click_button 'Accept'

    visit project_show_path(project: project)
    expect(find(:id, 'project-title')).to have_text('My Title hopefully got changed')
    expect(find(:id, 'description-text')).to have_text('New description. Not kidding.. Brand new!')
  end

  describe 'branching' do
    let(:other_user) { create(:confirmed_user, login: 'other_user') }
    let!(:package_of_another_project) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }

    before do
      login user
      visit project_show_path(project)
      click_link('Branch Existing Package')
    end

    scenario 'an existing package to an invalid target package or project' do
      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      fill_in('Branch package name', with: 'something/illegal')
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Failed to branch: Validation failed: Name is illegal')
      expect(page).to have_current_path(project_show_path('home:Jane'))
    end

    scenario 'a non-existing package' do
      fill_in('linked_project', with: 'non-existing_package')
      fill_in('linked_package', with: package_of_another_project.name)
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page).to have_current_path(project_show_path('home:Jane'))
    end

    scenario 'a package with disabled access flag' do
      create(:access_flag, status: 'disable', project: other_user.home_project)

      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      fill_in('Branch package name', with: 'some_different_name')
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Failed to branch: Package does not exist.')
      expect(page).to have_current_path(project_show_path('home:Jane'))
    end

    scenario 'a package with disabled sourceaccess flag' do
      create(:sourceaccess_flag, status: 'disable', project: other_user.home_project)

      fill_in('linked_project', with: other_user.home_project_name)
      fill_in('linked_package', with: package_of_another_project.name)
      fill_in('Branch package name', with: 'some_different_name')
      # This needs global write through
      click_button('Accept')

      expect(page).to have_text('Sorry, you are not authorized to branch this Package.')
      expect(page).to have_current_path(project_show_path('home:Jane'))
    end
  end
end
