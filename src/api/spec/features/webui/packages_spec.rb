require 'browser_helper'
require 'webmock/rspec'
require 'code_mirror_helper'

RSpec.describe 'Packages', type: :feature, js: true, vcr: true do
  it_behaves_like 'bootstrap user tab' do
    let(:package) do
      create(:package, name: 'group_test_package',
                       project_id: user_tab_user.home_project.id)
    end
    let!(:maintainer_user_role) { create(:relationship, package: package, user: user_tab_user) }
    let(:project_path) { package_show_path(project: user_tab_user.home_project, package: package) }
  end

  let!(:user) { create(:confirmed_user, :with_home, login: 'package_test_user') }
  let!(:package) { create(:package_with_file, name: 'test_package', project: user.home_project) }
  let(:other_user) { create(:confirmed_user, :with_home, login: 'other_package_test_user') }
  let!(:other_users_package) { create(:package_with_file, name: 'branch_test_package', project: other_user.home_project) }
  let(:package_with_develpackage) { create(:package, name: 'develpackage', project: user.home_project, develpackage: other_users_package) }
  let(:third_project) { create(:project_with_package, package_name: 'develpackage') }

  describe 'Viewing a package that' do
    let(:branching_data) { BranchPackage.new(project: user.home_project.name, package: package.name).branch }
    let(:branched_project) { Project.where(name: branching_data[:data][:targetproject]).first }
    let(:package_mime) do
      create(:package, name: 'test.yaml', project: user.home_project, description: 'A package with a mime type suffix')
    end

    before do
      # Needed for branching
      User.session = user
    end

    it "has a mime like suffix in it's name" do
      visit package_show_path(project: user.home_project, package: package_mime)
      expect(page).to have_text('test.yaml')
      expect(page).to have_text('A package with a mime type suffix')
    end

    it 'was branched' do
      visit package_show_path(project: branched_project, package: branched_project.packages.first)
      expect(page).to have_text("Links to #{user.home_project} / #{package}")
    end

    it 'has derived packages' do
      # Trigger branch creation
      branched_project.update_packages_if_dirty

      visit package_show_path(project: user.home_project, package: package)
      expect(page).to have_text('1 derived package')
      click_link('derived package')
      sleep 1 # Needed to avoid a flickering test. Sometimes the modal is shown too late and the click doen't work
      expect(page).to have_link('home:package_test_user...ome:package_test_user')
      click_link('home:package_test_user...ome:package_test_user')
      # Wait for the new page being loaded (aka. the ajax request to finish)
      expect(page).to have_text("Links to #{user.home_project} / #{package}")
      expect(page).to have_current_path(package_show_path(project: branched_project, package: branched_project.packages.first), ignore_query: true)
    end
  end

  describe 'editing package files' do
    let(:file_edit_test_package) { create(:package_with_file, name: 'file_edit_test_package', project: user.home_project) }

    before do
      login(user)
      visit package_show_path(project: user.home_project, package: file_edit_test_package)
    end

    it 'editing an existing file' do
      # somefile.txt is a file of our test package
      click_link('somefile.txt')
      # Workaround to update codemirror text field
      execute_script("$('.CodeMirror')[0].CodeMirror.setValue('added some new text')")
      click_button('Save')

      expect(page).to have_text("The file 'somefile.txt' has been successfully saved.")
      expect(file_edit_test_package.source_file('somefile.txt')).to eq('added some new text')
    end
  end

  describe 'editing the package description' do
    let(:file_edit_test_package) { create(:package_with_file, name: 'file_edit_test_package', project: user.home_project) }

    before do
      login(user)
      visit package_show_path(project: user.home_project, package: file_edit_test_package)
    end

    it 'updated the package description' do
      click_link('Edit description')
      within('.modal-body') do
        fill_in('Title:', with: 'Updated title')
        fill_in('Description:', with: 'Updated description')
      end
      within('.modal-footer') do
        click_on('Update')
      end
      expect(page).to have_text('was saved successfully')
      within('.basic-info') do
        expect(page).to have_text('Updated title')
        expect(page).to have_text('Updated description')
      end
    end
  end

  describe 'existing requests' do
    let(:source_project) { create(:project_with_package, name: 'source_project') }
    let(:source_package) { source_project.packages.first }
    let!(:bs_request) do
      create(:bs_request_with_submit_action,
             source_package: source_package,
             target_package: package)
    end

    it 'see a request' do
      login user
      visit package_show_path(package: package, project: user.home_project)
      click_link('Requests')
      expect(page).to have_css('table#all_requests_table tbody tr', count: 1)
      find('a', class: 'request_link').click
      expect(page).to have_current_path(/\/request\/show\/\d+/)
    end
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

    it 'via live build log' do
      visit package_live_build_log_path(project: user.home_project, package: package, repository: repository.name, arch: 'x86_64')
      click_link('Trigger Rebuild', match: :first)
      expect(a_request(:post, rebuild_url)).to have_been_made.once
    end

    it 'via binaries view' do
      allow(Buildresult).to receive(:find_hashed)
        .with(project: user.home_project, package: package.name, repository: repository.name, view: ['binarylist', 'status'])
        .and_return(Xmlhash.parse(fake_buildresult))

      visit package_binaries_path(project: user.home_project, package: package, repository: repository.name)
      click_link('Trigger')
      expect(a_request(:post, rebuild_url)).to have_been_made.once
    end
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

    it 'live build finishes succesfully' do
      visit package_live_build_log_path(project: user.home_project, package: package, repository: repository.name, arch: 'i586')

      find('#status', text: 'Build') # to wait until it loads
      expect(page).to have_text('Build')
      expect(page).to have_text('[1] this is my dummy logfile -> ümlaut')
    end

    it 'download logfile succesfully' do
      visit package_show_path(project: user.home_project, package: package)
      # test reload and wait for the build to finish
      find('.build-refresh').click
      find('#package-buildstatus a', text: 'succeeded').click
      expect(page).to have_text('[1] this is my dummy logfile -> ümlaut')
      first(:link, 'Download logfile').click
      # don't bother with the umlaut
      expect(page.source).to have_text('[1] this is my dummy logfile')
    end
  end

  it 'adding a valid file' do
    login user

    visit package_show_path(project: user.home_project, package: package)
    click_link('Add File')

    fill_in 'Filename', with: 'new_file'
    click_button('Add File')

    expect(page).to have_text("The file 'new_file' has been successfully saved.")
    expect(page).to have_link('new_file')
  end

  it 'adding an invalid file' do
    login user

    visit package_show_path(project: user.home_project, package: package)
    click_link('Add File')

    fill_in 'Filename', with: 'inv/alid'
    click_button('Add File')

    expect(page).to have_text("Error while creating 'inv/alid' file: 'inv/alid' is not a valid filename.")

    click_link(package.name)
    expect(page).not_to have_link('inv/alid')
  end

  describe 'branching a package from another users project' do
    before do
      login user
      allow(Configuration).to receive(:cleanup_after_days).and_return(14)
      visit package_show_path(project: other_user.home_project, package: other_users_package)
      click_link('Branch Package')
    end

    it 'with AutoCleanup' do
      click_button('Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package)
      )
      visit index_attribs_path(project: user.branch_project_name(other_user.home_project_name))
      expect(page).to have_text('OBS:AutoCleanup')
    end

    it 'without AutoCleanup' do
      find('summary').click
      find('label[for="disable-autocleanup"]').click
      click_button('Branch')

      expect(page).to have_text('Successfully branched package')
      expect(page).to have_current_path(
        package_show_path(project: user.branch_project_name(other_user.home_project_name), package: other_users_package)
      )
      visit index_attribs_path(project: user.branch_project_name(other_user.home_project_name))
      expect(page).to have_text('No attributes set')
    end
  end

  it 'requesting package deletion' do
    login user
    visit package_show_path(package: other_users_package, project: other_user.home_project)
    click_link('Request Deletion')

    expect(page).to have_text('Do you really want to request the deletion of package ')
    fill_in('bs_request_description', with: 'Hey, why not?')
    expect { click_button('Request') }.to change(BsRequest, :count).by(1)

    # The project name can be ellipsed when it's too long, so this explains why it's hardcoded in the spec
    expect(page).to have_text("Delete package home:othe...test_user / #{other_users_package}")
    expect(page).to have_css('#description-text', text: 'Hey, why not?')
    expect(page).to have_text('In state new')
  end

  it "changing the package's devel project" do
    login user
    visit package_show_path(package: package_with_develpackage, project: user.home_project)

    click_link('Request Devel Project Change')

    fill_in('New Devel Project:', with: third_project.name)
    fill_in('Description:', with: 'Hey, why not?')
    click_button('Request')

    request = BsRequest.where(description: 'Hey, why not?', creator: user.login, state: 'review')
    expect(request).to exist
    expect(page).to have_current_path("/request/show/#{request.first.number}")
    expect(page).to have_text(/Created by\s+#{user.login}/)
    expect(page).to have_text('In state review')
    expect(page).to have_text("Set the devel project to package #{third_project.name} / develpackage for package #{user.home_project} / develpackage")
  end

  it 'editing a package' do
    login user
    visit package_show_path(package: package, project: user.home_project)
    click_link('Edit description')
    sleep 1 # FIXME: Needed to avoid a flickering test.

    within('#edit-modal') do
      fill_in('title', with: 'test title')
      fill_in('description', with: 'test description')
      click_button('Update')
    end

    expect(find('#flash')).to have_text("Package data for '#{package}' was saved successfully")
    expect(page).to have_text('test title')
    expect(page).to have_text('test description')
  end

  context 'meta configuration' do
    describe 'as admin' do
      let!(:admin_user) { create(:admin_user) }

      before do
        login admin_user
      end

      it 'can edit' do
        visit package_meta_path(package.project, package)
        fill_in_editor_field('<!-- Comment for testing -->')
        find('.save').click
        expect(page).to have_text('The Meta file has been successfully saved.')
        expect(page).to have_css('.CodeMirror-code', text: 'Comment for testing')
      end
    end

    describe 'as common user' do
      let(:other_user) { create(:confirmed_user, :with_home, login: 'common_user') }

      before do
        login other_user
      end

      it 'can not edit' do
        visit package_meta_path(package.project, package)
        within('.card-body') do
          expect(page).not_to have_css('.toolbar')
        end
      end
    end
  end

  context 'creating a package' do
    describe 'in a project owned by the user, eg. home projects' do
      let(:very_long_description) { Faker::Lorem.paragraph(sentence_count: 20) }

      before do
        login user
        visit project_show_path(project: user.home_project)
        # TODO: Remove once responsive_ux is out of beta.
        if page.has_link?('Actions')
          click_menu_link('Actions', 'Create Package')
        else
          click_link('Create Package')
        end
      end

      it 'with invalid data (validation fails)' do
        expect(page).to have_text("Create Package for #{user.home_project_name}")
        fill_in 'package_name', with: 'cool stuff'
        click_button('Create')

        expect(page).to have_text("Invalid package name: 'cool stuff'")
        expect(page).to have_current_path("/package/new/#{user.home_project_name}", ignore_query: true)
      end

      it 'that already exists' do
        expect(page).to have_text("Create Package for #{user.home_project_name}")
        create(:package, name: 'coolstuff', project: user.home_project)

        fill_in 'package_name', with: 'coolstuff'
        click_button('Create')

        expect(page).to have_text("Package 'coolstuff' already exists in project '#{user.home_project_name}'")
        expect(page).to have_current_path("/package/new/#{user.home_project_name}", ignore_query: true)
      end

      it 'with valid data' do
        expect(page).to have_text("Create Package for #{user.home_project_name}")
        fill_in 'package_name', with: 'coolstuff'
        fill_in 'package_title', with: 'cool stuff everyone needs'
        fill_in 'package_description', with: very_long_description
        click_button 'Create'

        expect(page).to have_text("Package 'coolstuff' was created successfully")
        expect(page).to have_current_path(package_show_path(project: user.home_project_name, package: 'coolstuff'))
        expect(find(:css, '#package-title')).to have_text('cool stuff everyone needs')
        expect(find(:css, '#description-text')).to have_text(very_long_description)
      end
    end

    describe 'in a project not owned by the user, eg. global namespace' do
      let(:admin_user) { create(:admin_user, :with_home) }
      let(:global_project) { create(:project, name: 'global_project') }

      it 'as non-admin user' do
        login other_user
        visit project_show_path(project: global_project)
        # TODO: Remove `if` once responsive_ux is out of beta.
        click_link('Actions') if page.has_link?('Actions')
        expect(page).not_to have_link('Create package')

        # Use direct path instead
        visit "/package/new/#{global_project}"

        expect(page).to have_text('Sorry, you are not authorized to create this Package')
        expect(page).to have_current_path(root_path, ignore_query: true)
      end

      it 'as an admin' do
        login admin_user
        visit project_show_path(project: global_project)
        # TODO: Remove once responsive_ux is out of beta.
        if page.has_link?('Actions')
          click_menu_link('Actions', 'Create Package')
        else
          click_link('Create Package')
        end

        fill_in 'package_name', with: 'coolstuff'
        click_button('Create')

        expect(page).to have_text("Package 'coolstuff' was created successfully")
        expect(page).to have_current_path(package_show_path(project: global_project.to_s, package: 'coolstuff'), ignore_query: true)
      end
    end
  end
end
