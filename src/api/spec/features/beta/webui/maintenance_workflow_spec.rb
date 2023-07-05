require 'browser_helper'

RSpec.describe 'MaintenanceWorkflow', js: true, vcr: false do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:maintenance_coord_user) { create(:confirmed_user, :with_home, login: 'maintenance_coord') }
  let(:project) { create(:project_with_repository, name: 'openSUSE:11.4') }
  let(:another_project) { create(:project_with_repository, name: 'openSUSE:11.5') }
  let!(:package) { create(:package_with_file, project: project, name: 'cacti') }
  let!(:another_package) { create(:package_with_file, project: another_project, name: 'cacti') }
  let(:update_project) { create(:update_project, maintained_project: project, name: "#{project}:Update") }
  let(:another_update_project) { create(:update_project, maintained_project: another_project, name: "#{another_project}:Update") }
  let(:bs_request) { BsRequest.last }

  before do
    User.session = admin_user
    create(:maintenance_project_attrib, project: maintenance_project)
  end

  let(:maintenance_project) do
    create(:maintenance_project,
            name: 'MaintenanceProject',
            title: 'official maintenance space',
            target_project: [update_project, another_update_project],
            maintainer: maintenance_coord_user)
  end

  it "maintenance workflow without patchinfo" do
    # # Step 1: The user branches a package
    # ####################################
    login(user)

    # visit package_show_path(project: update_project, package: package)
    # desktop? ? click_link('Branch Package') : click_menu_link('Actions', 'Branch Package')
    # expect(page).to have_text('Source')

    # click_button('Branch')

    # expect(page).to have_text('Successfully branched package')

    user.run_as { BranchPackage.new(package: package.name).branch }
    update_project_branch = Project.last
    Backend::Connection.put("/source/#{update_project_branch.name}/#{update_project_branch.packages.last.name}/DUMMY_FILE", 'dummy')

    # Create the patchinfo
    visit project_show_path(project: Project.last.name)
    # binding.pry
    # click_link('Create Patchinfo')
    # fill_in('patchinfo_summary', with: 'ProjectWithRepo_package is much better than the old one')
    # fill_in('patchinfo_description', with: 'Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing')
    # check('patchinfo_block')
    # fill_in('patchinfo_block_reason', with: 'locked!')
    # click_button('Save')
    # expect(page).to have_css('#flash', text: 'Successfully edited patchinfo')

    # Step 2: The user submits the update creating a maintenance incident
    #####################################################################
    visit project_show_path(project: Project.last.name)

    # expect(page).to have_text("patchinfo")

    desktop? ? click_link('Submit as Update') : click_menu_link('Actions', 'Submit as Update')
    expect(page).to have_title('Submit as Update')
    fill_in('description', with: 'I want the update')
    save_screenshot('about to submit the update.png')
    binding.pry
    click_button('Submit')

    expect(page).to have_text('Created maintenance incident request')

    logout

    # Step 3: The maintenance coordinator accepts the request
    #########################################################
    login(maintenance_coord_user)

    visit request_show_path(bs_request)
    save_screenshot('maintenance_request.png')
    expect(page).to have_text('This is a Maintenance Incident')
    fill_in('reason', with: 'really? ok')

    click_button('Accept request')
    expect(page).to have_text("Request #{bs_request.number} accepted")

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
    visit project_show_path(project: update_project_branch.name)

    desktop? ? click_link('Submit as Update') : click_menu_link('Actions', 'Submit as Update')
    expect(page).to have_title('Submit as Update')
    fill_in('description', with: 'I have a additional fix')
    click_button('Submit')

    logout
  end
end
