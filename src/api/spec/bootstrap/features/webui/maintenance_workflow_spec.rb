require 'browser_helper'

RSpec.feature 'Bootstrap_MaintenanceWorkflow', type: :feature, js: true, vcr: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:maintenance_coord_user) { create(:confirmed_user, login: 'maintenance_coord') }
  let(:project) { create(:project_with_repository, name: 'ProjectWithRepo') }
  let(:package) { create(:package_with_file, project: project, name: 'ProjectWithRepo_package') }
  let(:update_project) { create(:update_project, target_project: project, name: "#{project.name}:Update") }
  let(:maintenance_project) do
    create(:maintenance_project,
           name: 'MaintenanceProject',
           title: 'official maintenance space',
           target_project: update_project,
           create_patchinfo: true,
           maintainer: maintenance_coord_user)
  end

  before do
    User.current = admin_user
    create(:maintenance_project_attrib, project: maintenance_project)
  end

  scenario 'maintenance workflow' do
    # Step 1: The user branches a package
    ####################################
    login(user)

    visit package_show_path(project: update_project, package: package)

    click_link('Branch package')
    sleep 1 # Needed to avoid a flickering test.
    expect(page).to have_text('Source')

    within('#branch-modal .modal-footer') do
      click_button('Accept')
    end
    expect(page).to have_text('Successfully branched package')

    # change the package sources so we have a difference
    Backend::Connection.put('/source/home:tom:branches:ProjectWithRepo:Update/ProjectWithRepo_package/DUMMY_FILE', 'dummy')

    # Step 2: The user submits the update
    #####################################
    visit project_show_path(project: 'home:tom:branches:ProjectWithRepo:Update')

    click_link('Submit as update')
    # we need this find to wait for the dialog to appear
    expect(find(:css, '.dialog h2')).to have_text('Submit as Update')
    fill_in('description', with: 'I want the update')

    click_button('Ok')
    expect(page).to have_css('#flash-messages', text: 'Created maintenance incident request')

    # Check that sending maintenance updates adds the source revision
    new_bs_request_action = BsRequestAction.where(
      type:                  'maintenance_incident',
      target_project:        maintenance_project.name,
      target_releaseproject: update_project.name,
      source_project:        "#{user.home_project}:branches:#{update_project.name}",
      source_package:        package.name
    )
    expect(new_bs_request_action.pluck(:source_rev).first).not_to be(nil)

    logout

    # Step 3: The maintenance coordinator accepts the request
    #########################################################
    login(maintenance_coord_user)

    visit request_show_path(BsRequest.last)

    fill_in('reason', with: 'really? ok')

    click_button('accept_request_button')
    expect(page).to have_css('#flash-messages', text: "Request #{BsRequest.last.number} accepted")

    # Step 4: The maintenance coordinator edits the patchinfo file
    ##############################################################
    # FIXME: Editing patchinfos should be it's own spec...
    visit(patchinfo_edit_patchinfo_path(package: 'patchinfo', project: 'MaintenanceProject:0'))

    # needed for patchinfo validation
    fill_in('summary', with: 'ProjectWithRepo_package is much better than the old one')
    fill_in('description', with: 'Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing')
    check('block')
    fill_in('block_reason', with: 'locked!')

    click_button('Save Patchinfo')
    expect(page).to have_css('#flash-messages', text: 'Successfully edited patchinfo')
    expect(find(:css, '.ui-state-error b')).to have_text('This update is currently blocked:')

    click_link('Edit patchinfo')
    uncheck('block')
    expect(page).to have_css('input[id=block_reason][disabled]')
    click_button 'Save Patchinfo'

    logout

    # Step 5: The user adds an additional fix to the incident
    #########################################################
    login(user)
    visit project_show_path(project: 'home:tom:branches:ProjectWithRepo:Update')

    click_link('Submit as update')

    expect(find(:css, '.dialog h2')).to have_text('Submit as Update')
    fill_in('description', with: 'I have a additional fix')
    click_button('Ok')

    logout

    # Step 6: The maintenance coordinator adds the new submit to the running incident
    #################################################################################
    login(maintenance_coord_user)

    visit request_show_path(BsRequest.last)
    click_link('Merge with existing incident')
    # we need this find to wait for the dialog to appear
    expect(find(:css, '.dialog h2')).to have_text('Set Incident')

    fill_in('incident_project', with: 2)

    click_button('Ok')
    expect(page).to have_css('#flash-messages', text: 'Incident MaintenanceProject:2 does not exist')

    click_link('Merge with existing incident')
    # we need this find to wait for the dialog to appear
    expect(find(:css, '.dialog h2')).to have_text('Set Incident')

    fill_in('incident_project', with: 0)

    click_button('Ok')
    expect(page).to have_css('#flash-messages', text: 'Set target of request 2 to incident 0')

    click_button('accept_request_button')

    # Step 7: The maintenance coordinator releases the request
    ##########################################################
    visit project_show_path('MaintenanceProject:0')
    click_link('Request to release')

    fill_in('description', with: 'RELEASE!')
    click_button('Ok')

    # As we can't release without build results this should fail
    expect(page).to have_css('#flash-messages',
                             text: "The repository 'MaintenanceProject:0' / 'ProjectWithRepo_Update' / i586 did not finish the build yet")
  end
end
