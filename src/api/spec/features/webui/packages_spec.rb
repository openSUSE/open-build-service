require 'browser_helper'
require 'webmock/rspec'

# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.feature 'Packages', type: :feature, js: true do
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

  describe 'Viewing a package that' do
    let(:branching_data) { BranchPackage.new(project: user.home_project.name, package: package.name).branch }
    let(:branched_project) { Project.where(name: branching_data[:data][:targetproject]).first }
    let(:package_mime) do
      create(:package, name: 'test.json', project: user.home_project, description: 'A package with a mime type suffix')
    end

    before do
      # Needed for branching
      User.current = user
    end

    scenario "has a mime like suffix in it's name" do
      visit package_show_path(project: user.home_project, package: package_mime)
      expect(page).to have_text('test.json')
      expect(page).to have_text('A package with a mime type suffix')
    end

    scenario 'was branched' do
      visit package_show_path(project: branched_project, package: branched_project.packages.first)
      expect(page).to have_text("Links to #{user.home_project} / #{package}")
    end

    scenario 'has derived packages' do
      # Trigger branch creation
      branched_project.update_packages_if_dirty

      visit package_show_path(project: user.home_project, package: package)
      expect(page).to have_text('1 derived package')
      click_link('derived package')
      expect(page).to have_link('home:package_test_user...ome:package_test_user')
      click_link('home:package_test_user...ome:package_test_user')
      expect(page.current_path).to eq(package_show_path(project: branched_project, package: branched_project.packages.first))
    end
  end

  describe 'branching a package' do
    after do
      # Cleanup backend
      if CONFIG['global_write_through']
        Backend::Connection.delete("/source/#{CGI.escape(other_user.home_project_name)}")
        Backend::Connection.delete("/source/#{CGI.escape(user.branch_project_name(other_user.home_project_name))}")
      end
    end

    scenario "from another user's project" do
      login user
      visit package_show_path(project: other_user.home_project, package: other_users_package)

      click_link('Branch package')
      click_button('Ok')

      expect(page).to have_text('Successfully branched package')
      expect(page.current_path).to eq(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package)
      )
    end
  end

  describe 'editing package files' do
    let(:file_edit_test_package) { create(:package_with_file, name: 'file_edit_test_package', project: user.home_project) }

    before do
      login(user)
      visit package_show_path(project: user.home_project, package: file_edit_test_package)
    end

    scenario 'editing an existing file' do
      skip('This started to fail due to js issues in rails 5. Please fix it:-)')
      # somefile.txt is a file of our test package
      click_link('somefile.txt')
      # Workaround to update codemirror text field
      execute_script("$('.CodeMirror')[0].CodeMirror.setValue('added some new text')")
      click_button('Save')

      expect(page).to have_text("The file 'somefile.txt' has been successfully saved.")
      expect(file_edit_test_package.source_file('somefile.txt')).to eq('added some new text')
    end
  end

  scenario 'deleting a package' do
    login user
    visit package_show_path(package: package, project: user.home_project)
    click_link('delete-package')
    expect(find('#del_dialog')).to have_text('Do you really want to delete this package?')
    click_button('Ok')
    expect(find('#flash-messages')).to have_text('Package was successfully removed.')
  end

  scenario 'requesting package deletion' do
    login user
    visit package_show_path(package: other_users_package, project: other_user.home_project)
    click_link('Request deletion')
    expect(page).to have_text('Do you really want to request the deletion of package ')
    click_button('Ok')
    expect(page).to have_text('Created repository delete request')
    find('a', text: /repository delete request \d+/).click
    expect(page.current_path).to match('/request/show/\\d+')
  end

  scenario "changing the package's devel project" do
    login user
    visit package_show_path(package: package_with_develpackage, project: user.home_project)
    click_link('Request devel project change')
    fill_in 'description', with: 'Hey, why not?'
    fill_in 'devel_project', with: third_project.name
    click_button 'Ok'

    expect(find('#flash-messages').text).to be_empty
    request = BsRequest.where(description: 'Hey, why not?', creator: user.login, state: 'review')
    expect(request).to exist
    expect(page.current_path).to match("/request/show/#{request.first.number}")
    expect(page).to have_text("Created by #{user.login}")
    expect(page).to have_text('In state review')
    expect(page).to have_text("Set the devel project to package #{third_project.name} / develpackage for package #{user.home_project} / develpackage")
  end

  context 'triggering package rebuild' do
    let(:repository) { create(:repository, name: 'package_test_repository', project: user.home_project, architectures: ['x86_64']) }
    let(:rebuild_url) do
      "#{CONFIG['source_url']}/build/#{user.home_project.name}?cmd=rebuild&arch=x86_64&package=#{package.name}&repository=#{repository.name}"
    end
    let(:fake_buildresult) do
      "<resultlist state='123'>
         <result project='#{user.home_project.name}' repository='#{repository.name}' arch='x86_64'>
           <binarylist/>
         </result>
       </resultlist>"
    end

    before do
      login(user)
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?arch=x86_64&package=#{package}&repository=#{repository.name}&view=status"
      stub_request(:get, path).and_return(body: fake_buildresult)
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/x86_64/_builddepinfo?package=#{package}&view=revpkgnames"
      stub_request(:get, path).and_return(body: '<builddepinfo />')
    end

    scenario 'via live build log' do
      visit package_live_build_log_path(project: user.home_project, package: package, repository: repository.name, arch: 'x86_64')
      click_link('Trigger Rebuild', match: :first)
      expect(a_request(:post, rebuild_url)).to have_been_made.once
    end

    scenario 'via binaries view' do
      allow(Buildresult).to receive(:find_hashed).
        with(project: user.home_project, package: package, repository: repository.name, view: %w(binarylist status)).
        and_return(Xmlhash.parse(fake_buildresult))

      visit package_binaries_path(project: user.home_project, package: package, repository: repository.name)
      click_link('Trigger')
      expect(a_request(:post, rebuild_url)).to have_been_made.once
    end
  end

  context 'log' do
    let(:repository) { create(:repository, name: 'package_test_repository', project: user.home_project, architectures: ['i586']) }

    before do
      login(user)
      stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/#{package}/_log?end=65536&nostream=1&start=0")
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
        .and_return(headers: { 'Content-Type'=> 'text/plain' }, body: '<directory><entry size="1"/></directory>')
      stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/#{package}/_log")
        .and_return(headers: { 'Content-Type'=> 'text/plain' }, body: '[1] this is my dummy logfile -> ümlaut')
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/#{repository.name}/i586/_builddepinfo?package=#{package}&view=revpkgnames"
      stub_request(:get, path).and_return(body: '<builddepinfo />')
    end

    scenario 'live build finishes succesfully' do
      visit package_live_build_log_path(project: user.home_project, package: package, repository: repository.name, arch: 'i586')
      expect(page).to have_text('Build finished')
      expect(page).to have_text('[1] this is my dummy logfile -> ümlaut')
    end

    scenario 'download logfile succesfully' do
      visit package_show_path(project: user.home_project, package: package)
      # test reload and wait for the build to finish
      find('.icons-reload').click
      find('.buildstatus a', text: 'succeeded').click
      expect(page).to have_text('[1] this is my dummy logfile -> ümlaut')
      first(:link, 'Download logfile').click
      # don't bother with the umlaut
      expect(page.source).to have_text('[1] this is my dummy logfile')
    end
  end

  scenario 'adding a valid file' do
    login user

    visit package_show_path(project: user.home_project, package: package)
    click_link('Add file')

    fill_in 'Filename', with: 'new_file'
    click_button('Save changes')

    expect(page).to have_text("The file 'new_file' has been successfully saved.")
    expect(page).to have_link('new_file')
  end

  scenario 'adding an invalid file' do
    login user

    visit package_show_path(project: user.home_project, package: package)
    click_link('Add file')

    fill_in 'Filename', with: 'inv/alid'
    click_button('Save changes')

    expect(page).to have_text("Error while creating 'inv/alid' file: 'inv/alid' is not a valid filename.")

    click_link(package.name)
    expect(page).not_to have_link('inv/alid')
  end
end
