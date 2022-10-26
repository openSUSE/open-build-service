require 'browser_helper'

RSpec.describe 'MaintainedProjects', js: true do
  let!(:admin_user) { create(:admin_user) }
  let(:opensuse_project) { create(:project, name: 'openSUSE') }
  let(:opensuse_project_update) { create(:project, name: 'openSUSE_Update') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project', target_project: opensuse_project) }

  describe 'index page' do
    context 'without login' do
      before do
        # The maintenance project factory needs a user logged in, so we fake it just for the creation
        admin_user.run_as { maintenance_project }
      end

      it 'maintenance projects are not shown' do
        visit project_maintained_projects_path(project_name: maintenance_project.name)
        expect(page).to have_text('Maintained Projects')
        expect(page).not_to have_selector('#new-maintenance-project-modal')
        expect(page).not_to have_selector('#delete-maintained-project-modal')
      end
    end

    context 'with admin login' do
      it 'initial state' do
        login admin_user
        visit project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_text('Maintained Projects')
        expect(page).to have_selector('#new-maintenance-project-modal', visible: :hidden)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: :hidden)
      end

      it 'click on add new project' do
        login admin_user
        visit project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_selector('#new-maintenance-project-modal', visible: :hidden)
        click_link('Add Project to Maintain')

        expect(page).to have_selector('#new-maintenance-project-modal', visible: :visible)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: :hidden)
      end

      it 'click on delete project' do
        login admin_user
        visit project_maintained_projects_path(project_name: maintenance_project.name)

        expect(page).to have_selector('#new-maintenance-project-modal', visible: :hidden)

        click_link('Delete Project')

        expect(page).to have_selector('#new-maintenance-project-modal', visible: :hidden)
        expect(page).to have_selector('#delete-maintained-project-modal', visible: :visible)
      end

      it 'delete project' do
        login admin_user
        visit project_maintained_projects_path(project_name: maintenance_project.name)

        click_link('Delete Project')

        expect(find_by_id('delete-maintained-project-modal')).to have_text('Disable Maintenance to this project?')

        within('#delete-maintained-project-modal .modal-footer') do
          expect(page).to have_button('Disable')
          click_button('Disable')
        end

        expect(page).to have_css('#flash')

        within('#flash') do
          expect(page).to have_text("Disabled maintenance for #{opensuse_project}")
        end
      end
    end
  end
end
