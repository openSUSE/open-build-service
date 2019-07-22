# typed: false
require 'browser_helper'

RSpec.feature 'Bootstrap_MaintainedProjects', type: :feature, js: true, vcr: true do
  let!(:admin_user) { create(:admin_user) }
  let(:openSUSE_project) { create(:project, name: 'openSUSE') }
  let(:openSUSE_project_update) { create(:project, name: 'openSUSE_Update') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project', target_project: openSUSE_project) }

  describe 'index page' do
    scenario 'without login' do
      visit projects_project_maintained_projects_path(project_name: maintenance_project.name)
      expect(page).to have_text('Maintained Projects')
      expect(page).not_to have_selector('#new-maintenance-project-modal')
      expect(page).not_to have_selector('#delete-maintained-project-modal')
    end

    context 'with admin login' do
      scenario 'initial state' do
        login admin_user
        visit projects_project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_text('Maintained Projects')
        expect(page).to have_selector('#new-maintenance-project-modal', visible: false)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: false)
      end

      scenario 'click on add new project' do
        login admin_user
        visit projects_project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_selector('#new-maintenance-project-modal', visible: false)
        click_link('Add Project to Maintain')

        expect(page).to have_selector('#new-maintenance-project-modal', visible: true)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: false)
      end

      scenario 'click on delete project' do
        login admin_user
        visit projects_project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_selector('#new-maintenance-project-modal', visible: false)

        click_link('Delete Project')

        expect(page).to have_selector('#new-maintenance-project-modal', visible: false)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: true)
      end

      scenario 'delete project' do
        login admin_user
        visit projects_project_maintained_projects_path(project_name: maintenance_project.name)

        click_link('Delete Project')

        expect(find('#delete-maintained-project-modal')).to have_text('Disable Maintenance to this project?')

        within('#delete-maintained-project-modal .modal-footer') do
          expect(page).to have_button('Disable')
          click_button('Disable')
        end

        expect(page).to have_css('#flash')

        within('#flash') do
          expect(page).to have_text("Disabled maintenance for #{openSUSE_project}")
        end
      end
    end
  end
end
