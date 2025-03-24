require 'browser_helper'

RSpec.describe 'MaintenanceWorkflow', :js, :vcr do
  let(:admin_user) { create(:admin_user) }
  let(:maintenance_project) do
    create(:maintenance_project,
           name: 'MaintenanceProject',
           title: 'official maintenance space',
           target_project: [update_project, another_update_project],
           maintainer: maintenance_coord_user)
  end
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:maintenance_coord_user) { create(:confirmed_user, :with_home, login: 'maintenance_coord') }

  let(:branched_project) do
    project = create(:project_with_repository, name: 'home:tom:branches:Update')
    create(:package_with_file, project: project, name: 'cacti.openSUSE_11.4_Update', file_name: 'DUMMY_FILE', file_content: 'boo#12345')
    create(:package_with_file, project: project, name: 'cacti.openSUSE_11.5_Update', file_name: 'DUMMY_FILE', file_content: 'boo#12345')
    project
  end

  let(:update_project) do
    project = create(:project_with_repository, name: 'openSUSE:11.4')
    create(:package_with_file, project: project, name: 'cacti')
    create(:update_project, maintained_project: project, name: "#{project}:Update")
  end

  let(:another_update_project) do
    project = create(:project_with_repository, name: 'openSUSE:11.5')
    create(:package_with_file, project: project, name: 'cacti')
    create(:update_project, maintained_project: project, name: "#{project}:Update")
  end

  context 'maintenance request without patchinfo' do
    let(:bs_request) do
      create(:bs_request_with_maintenance_incident_actions, source_project_name: branched_project.name, source_package_names: ['cacti'], target_project_name: maintenance_project.name,
                                                            target_releaseproject_names: [update_project.name, another_update_project.name])
    end

    before do
      login(admin_user)
      visit request_show_path(bs_request)
    end

    it 'displays information on type of request' do
      expect(page).to have_text('This is a Maintenance Incident')
    end

    context 'when accepting request' do
      before do
        login(maintenance_coord_user)

        visit request_show_path(bs_request)
        fill_in('reason', with: 'really? ok')

        click_button('Accept')
        click_button('Accept request')
      end

      it 'creates maintenance incident project' do
        expect(page).to have_text("Request #{bs_request.number} accepted")
        expect(bs_request.bs_request_actions.first.target_project).to eq('MaintenanceProject:0')
      end
    end
  end

  context 'maintenance request with patchinfo' do
    let(:bs_request) do
      user.run_as { create(:patchinfo, project_name: branched_project.name, package_name: 'patchinfo') }
      create(:bs_request_with_maintenance_incident_actions, :with_patchinfo, source_project_name: branched_project.name,
                                                                             source_package_names: ['cacti'],
                                                                             target_project_name: maintenance_project.name,
                                                                             target_releaseproject_names: [update_project.name, another_update_project.name])
    end

    before do
      login(admin_user)
      visit request_show_path(bs_request)
    end

    it 'displays information on type of request' do
      expect(page).to have_text('This is a Maintenance Incident')
    end

    it 'has patchinfo submission' do
      find_by_id('request-actions').click
      expect(page).to have_text('patchinfo')
    end

    context 'when accepting request' do
      before do
        login(maintenance_coord_user)

        visit request_show_path(bs_request)
        fill_in('reason', with: 'really? ok')

        click_button('Accept')
        click_button('Accept request')
      end

      it 'creates maintenance incident project' do
        expect(page).to have_text("Request #{bs_request.number} accepted")
        expect(bs_request.bs_request_actions.first.target_project).to eq('MaintenanceProject:0')
      end
    end
  end
end
