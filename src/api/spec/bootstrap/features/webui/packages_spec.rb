require 'browser_helper'
require 'webmock/rspec'
require 'code_mirror_helper'

RSpec.feature 'Bootstrap_Packages', type: :feature, js: true, vcr: true do
  it_behaves_like 'user tab' do
    let(:package) do
      create(:package, name: 'group_test_package',
        project_id: user_tab_user.home_project.id)
    end
    let!(:maintainer_user_role) { create(:relationship, package: package, user: user_tab_user) }
    let(:project_path) { package_show_path(project: user_tab_user.home_project, package: package) }
  end

  let!(:user) { create(:confirmed_user, login: 'package_test_user') }
  let!(:package) { create(:package_with_file, name: 'test_package', project: user.home_project) }
  let(:other_user) { create(:confirmed_user, login: 'other_package_test_user') }
  let!(:other_users_package) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }
  let(:package_with_develpackage) { create(:package, name: 'develpackage', project: user.home_project, develpackage: other_users_package) }
  let(:third_project) { create(:project_with_package, package_name: 'develpackage') }

  describe 'branching a package from another users project' do
    before do
      allow(Configuration).to receive(:cleanup_after_days).and_return(14)
      login user
      visit package_show_path(project: other_user.home_project, package: other_users_package)
      click_link('Branch package')
      sleep 1 # Needed to avoid a flickering test. Sometimes the summary is not expanded and its content not visible
    end

    scenario 'with AutoCleanup' do
      within('#branch-modal .modal-footer') do
        click_button('Accept')
      end

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package)
      )
      visit index_attribs_path(project: user.branch_project_name(other_user.home_project_name))
      expect(page).to have_text('OBS:AutoCleanup')
    end

    scenario 'without AutoCleanup' do
      within('#branch-modal') do
        find('summary').click
        find('label[for="disable-autocleanup"]').click
        click_button('Accept')
      end

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package)
      )
      visit index_attribs_path(project: user.branch_project_name(other_user.home_project_name))
      expect(page).to have_text('No attributes set')
    end
  end

  scenario 'deleting a package' do
    login user
    visit package_show_path(package: package, project: user.home_project)
    click_link('Delete package')

    expect(find('#delete-modal')).to have_text('Do you really want to delete this package?')
    within('#delete-modal .modal-footer') do
      click_button('Delete')
    end

    expect(find('#flash-messages')).to have_text('Package was successfully removed.')
  end

  scenario 'requesting package deletion' do
    login user

    visit package_show_path(package: other_users_package, project: other_user.home_project)
    click_link('Request deletion')

    expect(page).to have_text('Do you really want to request the deletion of package ')
    within('#delete-request-modal') do
      fill_in('description', with: 'Hey, why not?')
      click_button('Accept')
    end

    expect(page).to have_text('Created delete request')
    find('a', text: /delete request \d+/).click
    expect(page).to have_current_path(/\/request\/show\/\d+/)
  end

  scenario "changing the package's devel project" do
    login user

    visit package_show_path(package: package_with_develpackage, project: user.home_project)

    click_link('Request devel project change')

    within('#modal') do
      fill_in('devel_project', with: third_project.name)
      fill_in('description', with: 'Hey, why not?')
      click_button('Accept')
    end

    find('#flash-messages', visible: false)
    request = BsRequest.where(description: 'Hey, why not?', creator: user.login, state: 'review')
    expect(request).to exist
    expect(page).to have_current_path("/request/show/#{request.first.number}")
    expect(page).to have_text(/Created by\s+#{user.login}/)
    expect(page).to have_text('In state review')
    expect(page).to have_text("Set the devel project to package #{third_project.name} / develpackage for package #{user.home_project} / develpackage")
  end

  context 'log' do
    let(:repository) { create(:repository, name: 'package_test_repository', project: user.home_project, architectures: ['i586']) }

    before do
      login(user)
      stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/#{package}/_log?end=1&nostream=1&start=0")
        .and_return(body: '[1] this is my dummy logfile -> ümlaut')
      result = %(<resultlist state="8da2ae1e32481175f43dc30b811ad9b5">
                              <result project="#{user.home_project}" repository="#{repository.name}" arch="i586" code="published" state="published">
                                <status package="#{package}" code="succeeded" />
                              </result>
                            </resultlist>
                            )
      result_path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?"
      stub_request(:get, result_path + 'view=status&package=test_package&multibuild=1&locallink=1')
        .and_return(body: result)
      stub_request(:get, result_path + "arch=i586&package=#{package}&repository=#{repository.name}&view=status")
        .and_return(body: result)
      stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/#{package}/_log?view=entry")
        .and_return(headers: { 'Content-Type' => 'text/plain' }, body: '<directory><entry size="1"/></directory>')
      stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/#{package}/_log")
        .and_return(headers: { 'Content-Type' => 'text/plain' }, body: '[1] this is my dummy logfile -> ümlaut')
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/_builddepinfo?package=#{package}&view=revpkgnames"
      stub_request(:get, path).and_return(body: '<builddepinfo />')
    end

    scenario 'download logfile succesfully' do
      visit package_show_path(project: user.home_project, package: package)
      # test reload and wait for the build to finish
      find('.build-refresh').click
      find('.buildstatus a', text: 'succeeded').click
      expect(page).to have_text('[1] this is my dummy logfile -> ümlaut')
      first(:link, 'Download logfile').click
      # don't bother with the umlaut
      expect(page.source).to have_text('[1] this is my dummy logfile')
    end
  end

  context 'meta configuration' do
    describe 'as admin' do
      let!(:admin_user) { create(:admin_user) }

      before do
        login admin_user
      end

      scenario 'can edit' do
        visit package_meta_path(package.project, package)
        fill_in_editor_field('<!-- Comment for testing -->')
        click_button('Save')
        expect(page).to have_text('The Meta file has been successfully saved.')
        expect(page).to have_css('.CodeMirror-code', text: 'Comment for testing')
      end
    end

    describe 'as common user' do
      let(:other_user) { create(:confirmed_user, login: 'common_user') }
      before do
        login other_user
      end

      scenario 'can not edit' do
        visit package_meta_path(package.project, package)
        within('.card-body') do
          expect(page).not_to have_css('.toolbar')
        end
      end
    end
  end
end
