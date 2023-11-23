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
    project = create(:project_with_repository, maintainer: user, name: 'home:tom:branches:Update')
    create(:package_with_file, project: project, name: 'cacti.openSUSE_11.4_Update', file_name: 'DUMMY_FILE', file_content: 'boo#12345')
    create(:package_with_file, project: project, name: 'cacti.openSUSE_11.5_Update', file_name: 'DUMMY_FILE', file_content: 'boo#12345')
    project
  end

  let(:update_project) do
    project = create(:project_with_repository, name: 'openSUSE:11.4')
    create(:package_with_file, project: project, name: 'cacti')
    create(:package_with_file, project: project, name: 'cacti.openSUSE_11.4_Update')
    create(:update_project, maintained_project: project, name: "#{project}:Update")
  end

  let(:another_update_project) do
    project = create(:project_with_repository, name: 'openSUSE:11.5')
    create(:package_with_file, project: project, name: 'cacti')
    create(:update_project, maintained_project: project, name: "#{project}:Update")
  end

  context 'maintenance request without patchinfo' do
    let(:maintenance_request) do
      create(:bs_request_with_maintenance_incident_actions, source_project_name: branched_project.name, source_package_names: ['cacti'], target_project_name: maintenance_project.name,
                                                            target_releaseproject_names: [update_project.name, another_update_project.name])
    end

    before do
      login(admin_user)
      visit request_show_path(maintenance_request)
    end

    it 'displays information on type of request' do
      expect(page).to have_text('This is a Maintenance Incident')
    end

    context 'when accepting request' do
      before do
        login(maintenance_coord_user)

        visit request_show_path(maintenance_request)
        fill_in('reason', with: 'really? ok')

        click_button('Accept request')
      end

      it 'succeeds' do
        expect(page).to have_text("Request #{maintenance_request.number} accepted")
      end

      it 'creates maintenance incident project' do
        expect(maintenance_request.bs_request_actions.first.target_project).to eq('MaintenanceProject:0')
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

        click_button('Accept request')
      end

      it 'succeeds' do
        expect(page).to have_text("Request #{bs_request.number} accepted")
      end

      it 'creates maintenance incident project' do
        expect(bs_request.bs_request_actions.first.target_project).to eq('MaintenanceProject:0')
      end
    end
  end

  context 'release requests' do
    let(:maintenance_request) do
      create(:bs_request_with_maintenance_incident_actions, source_project_name: branched_project.name, source_package_names: ['cacti'], target_project_name: maintenance_project.name,
                                                            target_releaseproject_names: [update_project.name])
    end

    let(:release_request) do
      create(:bs_request_with_maintenance_release_actions, creator: user, description: 'Request with release actions',
                                                           source_project_name: 'MaintenanceProject:0',
                                                           package_names: ['cacti.openSUSE_11.4_Update'],
                                                           target_project_names: [update_project.name])
    end

    before do
      login(maintenance_coord_user)
      visit request_show_path(maintenance_request)
      fill_in('reason', with: 'really? ok')
      click_button('Accept request')
    end

    context 'when visiting the request page' do
      before do
        login(user)
        visit request_show_path(release_request)
      end

      it 'displays information on type of request' do
        expect(page).to have_text('This is a Maintenance Release request')
      end

      it 'displays request actions dropdown' do
        expect(page).to have_text('Release cacti.openSUSE_11.4_Update')
        expect(page).to have_text('Next')
      end
    end

    context 'when accepting the request' do
      before do
        update_project.store
        Project.find_by(name: 'MaintenanceProject:0').store
        login(admin_user)
        visit request_show_path(release_request)
        fill_in('reason', with: "Accepting the request #{release_request.number}")
        click_button('Accept request')
        release_request.reload
        visit request_show_path(release_request)
      end

      it 'shows the confirmation' do
        expect(page).to have_text("Request #{release_request.number} accepted")
      end

      it 'stores correct information' do
        expect(HistoryElement::RequestAccepted.last.comment).to eq("Accepting the request #{release_request.number}")
      end
    end
  end
end
