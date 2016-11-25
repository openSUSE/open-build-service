require 'browser_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the BsRequestAction methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.feature 'Projects', type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:maintenance_coord_user) { create(:confirmed_user, login: 'maintenance_coord') }
  let(:project) { create(:project_with_repository, name: 'ProjectWithRepo') }
  let(:package) { create(:package_with_file, project: project, name: 'ProjectWithRepo_package') }
  let!(:maintained_attrib) { create(:maintained_attrib, package: package) }
  let(:update_project) { create(:update_project, target_project: project, name: "#{project.name}:Update") }
  let(:maintenance_project) {
    create(:maintenance_project,
           name: 'MaintenanceProject',
           title: 'official maintenance space',
           target_project: update_project,
           create_patchinfo: true,
           maintainer: maintenance_coord_user)
  }

  scenario 'maintenance workflow' do
    # admin user add attribute 'OBS:Maintained' to project
    login(admin_user)

    visit project_show_path(project)

    click_link('Advanced')
    click_link('Attributes')
    click_link('Add a new attribute')
    select('OBS:Maintained', from: 'attrib_attrib_type_id')
    click_button('Create Attribute')
    expect(page).to have_text('Attribute was successfully created.')

    logout

    # user branch a package
    login(user)

    visit project_show_path(maintenance_project)
    expect(find(:id, 'project_title')).to have_text('official maintenance space')
    expect(find(:id, 'infos_list')).to have_text('1 maintained project')

    click_link('Maintained Projects')
    click_link('ProjectWithRepo:Update')
    expect(find(:id, 'infos_list')).to have_text('Maintained by MaintenanceProject')

    click_link('Inherited Packages')
    click_link('ProjectWithRepo_package')
    click_link('Branch package')
    expect(find(:id, 'branch_dialog')).to have_text('Do you really want to branch package')

    click_button('Ok')
    expect(page).to have_text('Successfully branched package')

    # do not die with unchanged package
    Suse::Backend.put("/source/home:tom:branches:ProjectWithRepo:Update/ProjectWithRepo_package/DUMMY_FILE", "dummy")

    visit project_show_path(project: 'home:tom')

    click_link('Subprojects')
    click_link('branches:ProjectWithRepo:Update')
    click_link('Submit as update')

    # wait for the dialog to appear
    expect(find(:css, '.dialog h2')).to have_text('Submit as Update')
    fill_in('description', with: 'I want the update')
    click_button('Ok')

    expect(find(:css, 'span.ui-icon.ui-icon-info')).to have_text('Created maintenance incident request')
    expect(find(:link, '1 open request')).to have_text('1 open request')
    expect(find(:link, '1 Release Target')).to have_text('1 Release Target')

    logout

    # now let the coordinator act
    login(maintenance_coord_user)

    visit project_show_path(project: maintenance_project)

    click_link('open request')
    expect(find(:id, 'description-text')).to have_text('I want the update')
    expect(find(:id, 'action_display_0')).to have_text('Release in ProjectWithRepo:Update')
    fill_in('reason', with: 'really? ok')
    click_button('accept_request_button')
    expect(find(:css, '#action_display_0')).to have_text(
      /Submit update from package home:tom:\.\.\.o:Update \/ ProjectWi\.\.\._package to package MaintenanceProject:0 \/ ProjectWi\.\.\.o_Update/
    )
    visit(project_show_path(project: 'MaintenanceProject:0'))
    find(:link, 'Patchinfo present').click
    find(:id, 'edit-patchinfo').click

    page.evaluate_script('window.confirm = function() { return true; }')
    find(:link, 'Update issues from sources').click
    expect(page).to have_content('Patchinfo-Editor for MaintenanceProject:0')

    expect(find(:id, 'summary')).to have_text('I want the update')

    fill_in('summary', with: 'ProjectWithRepo_package is much better than the old one')
    fill_in('description', with: 'Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing')
    check('block')
    fill_in('block_reason', with: 'locked!')
    click_button('Save Patchinfo')

    # summary and description are ok
    expect(page).to have_no_css('span.ui-icon.ui-icon-alert')

    expect(find(:css, 'span.ui-icon.ui-icon-info')).to have_text('Successfully edited patchinfo')
    expect(find(:css, '.ui-state-error b')).to have_text('This update is currently blocked:')

    click_link('MaintenanceProject')
    click_link('open incident')

    click_link('recommended')
    click_link('edit-patchinfo')
    uncheck('block')
    expect(page).to have_css('input[id=block_reason][disabled]')
    click_button 'Save Patchinfo'

    logout

    # add a additional fix to the incident
    login(user)
    visit project_show_path(project: 'home:tom:branches:ProjectWithRepo:Update')

    click_link('Submit as update')

    expect(find(:css, '.dialog h2')).to have_text('Submit as Update')
    fill_in('description', with: 'I have a additional fix')
    click_button('Ok')

    logout

    # let the maint-coordinator add the new submit to the running incident and cont
    login(maintenance_coord_user)
    visit project_show_path(project: 'MaintenanceProject')

    click_link('open request')
    expect(find(:id, 'description-text')).to have_text('I have a additional fix')
    click_link('Merge with existing incident')

    # set to not existing incident
    existing_incident = '0'
    non_existing_incident = '2'

    fill_in('incident_project', with: non_existing_incident)
    click_button('Ok')
    expect(find(:css, 'span.ui-icon.ui-icon-alert')).to have_text('does not exist')

    click_link('Merge with existing incident')
    fill_in('incident_project', with: existing_incident)
    click_button('Ok')

    expect(page).to have_css('span.ui-icon.ui-icon-info',
                             text: "Set target of request #{non_existing_incident} to incident #{existing_incident}")

    click_button('accept_request_button')

    # TODO: make it unique find(:link, "0").click
    visit project_show_path('MaintenanceProject:0')
    click_link('Request to release')

    fill_in('description', with: 'RELEASE!')
    click_button('Ok')

    # we can't release without build results
    expect(find(:css, 'span.ui-icon.ui-icon-alert')).to have_text(
      "The repository 'MaintenanceProject:0' / 'ProjectWithRepo_Update' / i586 did not finish the build yet")
  end
end
