require 'browser_helper'

RSpec.describe 'MaintenanceWorkflow', :js, :vcr do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:maintenance_coord_user) { create(:confirmed_user, :with_home, login: 'maintenance_coord') }
  let(:project) { create(:project_with_repository, name: 'ProjectWithRepo') }
  let(:package) { create(:package_with_file, project: project, name: 'ProjectWithRepo_package') }
  let(:update_project) { create(:update_project, maintained_project: project, name: "#{project}:Update") }
  let(:maintenance_project) do
    create(:maintenance_project,
           name: 'MaintenanceProject',
           title: 'official maintenance space',
           target_project: update_project,
           create_patchinfo: true,
           maintainer: maintenance_coord_user)
  end
  let(:bs_request) { BsRequest.last }

  before do
    User.session = admin_user
    create(:maintenance_project_attrib, project: maintenance_project)
  end

  it 'maintenance workflow' do
    # Step 1: The user branches a package
    ####################################
    login(user)

    visit package_show_path(project: update_project, package: package)

    desktop? ? click_link('Branch Package') : click_menu_link('Actions', 'Branch Package')
    expect(page).to have_text('Source')

    click_button('Branch')

    expect(page).to have_text('Successfully branched package')

    # change the package sources so we have a difference
    Backend::Connection.put('/source/home:tom:branches:ProjectWithRepo:Update/ProjectWithRepo_package/DUMMY_FILE', 'dummy')

    # Step 2: The user submits the update
    #####################################
    visit project_show_path(project: 'home:tom:branches:ProjectWithRepo:Update')

    desktop? ? click_link('Submit as Update') : click_menu_link('Actions', 'Submit as Update')
    expect(page).to have_title('Submit as Update')
    fill_in('description', with: 'I want the update')
    click_button('Submit')

    expect(page).to have_css('#flash', text: 'Created maintenance incident request')

    # Check that sending maintenance updates adds the source revision
    new_bs_request_action = BsRequestAction.where(
      type: 'maintenance_incident',
      target_project: maintenance_project.name,
      target_releaseproject: update_project.name,
      source_project: "#{user.home_project}:branches:#{update_project}",
      source_package: package.name
    )
    expect(new_bs_request_action.pick(:source_rev)).not_to be_nil

    logout

    # Step 3: The maintenance coordinator accepts the request
    #########################################################
    login(maintenance_coord_user)

    visit request_show_path(bs_request)

    fill_in('reason', with: 'really? ok')

    click_button('Accept request')
    # Looks like accepting the request takes some time, so we allow it to take a bit more than usual
    Capybara.using_wait_time(12.seconds) do
      expect(page).to have_css('#overview h3', text: "Request #{bs_request.number} accepted")
    end

    # Step 4: The maintenance coordinator edits the patchinfo file
    ##############################################################
    # FIXME: Editing patchinfos should be it's own spec...
    visit(edit_patchinfo_path(package: 'patchinfo', project: 'MaintenanceProject:0'))

    # needed for patchinfo validation
    fill_in('patchinfo_summary', with: 'ProjectWithRepo_package is much better than the old one')
    fill_in('patchinfo_description', with: 'Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing')
    check('patchinfo_block')
    fill_in('patchinfo_block_reason', with: 'locked!')

    click_button('Save')
    expect(page).to have_css('#flash', text: 'Successfully edited patchinfo')
    expect(find(:css, '.block-reason span:first-child')).to have_text('Release is blocked')

    click_link('Edit patchinfo')
    uncheck('patchinfo_block')
    expect(page).to have_css('input[id=patchinfo_block_reason][disabled]')
    click_button 'Save'

    logout

    # Step 5: The user adds an additional fix to the incident
    #########################################################
    login(user)
    visit project_show_path(project: 'home:tom:branches:ProjectWithRepo:Update')

    desktop? ? click_link('Submit as Update') : click_menu_link('Actions', 'Submit as Update')
    expect(page).to have_title('Submit as Update')
    fill_in('description', with: 'I have a additional fix')
    click_button('Submit')

    logout

    # FIXME: This isn't working anymore in Bootstrap.
    #        The link "Merge with existing incident" wasn't migrated. See #8207 on GitHub.
    # Step 6: The maintenance coordinator adds the new submit to the running incident
    #################################################################################
    # login(maintenance_coord_user)

    # visit request_show_path(BsRequest.last)
    # click_link('Merge with existing incident')
    # # we need this find to wait for the dialog to appear
    # expect(find(:css, '.dialog h2')).to have_text('Set Incident')

    # fill_in('incident_project', with: 2)

    # click_button('Accept')
    # expect(page).to have_css('#flash', text: 'Incident MaintenanceProject:2 does not exist')

    # click_link('Merge with existing incident')
    # # we need this find to wait for the dialog to appear
    # expect(find(:css, '.dialog h2')).to have_text('Set Incident')

    # fill_in('incident_project', with: 0)

    # click_button('Accept')
    # expect(page).to have_css('#flash', text: 'Set target of request 2 to incident 0')

    # click_button('Accept request')

    # expect(page).to have_css('#flash', text: 'Request 2 accepted')

    # # Step 7: The maintenance coordinator releases the request
    # ##########################################################
    # visit project_show_path('MaintenanceProject:0')
    # click_link('Request to Release')

    # # we need this find to wait for the dialog to appear
    # expect(find('#project-release-request-modal-label')).to have_text('Create Maintenance Release Request')
    # fill_in('description', with: 'RELEASE!')

    # within('#project-release-request-modal .modal-footer') do
    #   click_button('Accept')
    # end

    # # As we can't release without build results this should fail
    # expect(page).to have_css('#flash',
    #                          text: "The repository 'MaintenanceProject:0' / 'ProjectWithRepo_Update' / i586 did not finish the build yet")
  end
end
