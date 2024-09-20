require 'webmock/rspec'
RSpec.describe Webui::PackageController, :vcr do
  let(:admin) { create(:admin_user, login: 'admin') }
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:target_project) { create(:project) }
  let(:package) { create(:package_with_file, name: 'package_with_file', project: source_project) }
  let(:broken_service_package) { create(:package_with_broken_service, name: 'package_with_broken_service', project: source_project) }
  let(:repo_for_source_project) do
    repo = create(:repository, project: source_project, architectures: ['i586'], name: 'source_repo')
    source_project.store(login: user)
    repo
  end
  let(:fake_build_results) do
    <<-HEREDOC
      <resultlist state="2b71f05ecb8742e3cd7f6066a5097c72">
        <result project="home:tom" repository="#{repo_for_source_project.name}" arch="x86_64"
          code="unknown" state="unknown" dirty="true">
         <binarylist>
            <binary filename="image_binary.vhdfixed.xz" size="123312217"/>
            <binary filename="image_binary.xz.sha256" size="1531"/>
            <binary filename="_statistics" size="4231"/>
            <binary filename="updateinfo.xml" size="4231"/>
            <binary filename="rpmlint.log" size="121"/>
          </binarylist>
        </result>
      </resultlist>
    HEREDOC
  end
  let(:fake_build_results_without_binaries) do
    <<-HEREDOC
      <resultlist state="2b71f05ecb8742e3cd7f6066a5097c72">
        <result project="home:tom" repository="fake_repo_name" arch="i586" code="unknown" state="unknown" dirty="true">
         <binarylist>
          </binarylist>
        </result>
      </resultlist>
    HEREDOC
  end

  describe 'POST #remove' do
    before do
      login(user)
    end

    describe 'authentication' do
      let(:target_package) { create(:package, name: 'forbidden_package', project: target_project) }

      it 'does not allow other users than the owner to delete a package' do
        post :remove, params: { project: target_project, package: target_package }

        expect(flash[:error]).to eq('Sorry, you are not authorized to delete this package.')
        expect(target_project.packages).not_to be_empty
      end

      it "allows admins to delete other user's packages" do
        login(admin)
        post :remove, params: { project: target_project, package: target_package }

        expect(flash[:success]).to eq('Package was successfully removed.')
        expect(target_project.packages).to be_empty
      end
    end

    context 'a package' do
      before do
        post :remove, params: { project: user.home_project, package: source_package }
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:success]).to eq('Package was successfully removed.') }

      it 'deletes the package' do
        expect(user.home_project.packages).to be_empty
      end
    end

    context 'a package with dependencies' do
      let(:devel_project) { create(:package, project: target_project) }

      before do
        source_package.develpackages << devel_project
      end

      it 'does not delete the package and shows an error message' do
        post :remove, params: { project: user.home_project, package: source_package }

        expect(flash[:error]).to eq("Package can't be removed: used as devel package by #{target_project}/#{devel_project}")
        expect(user.home_project.packages).not_to be_empty
      end

      context 'forcing the deletion' do
        before do
          post :remove, params: { project: user.home_project, package: source_package, force: true }
        end

        it 'deletes the package' do
          expect(flash[:success]).to eq('Package was successfully removed.')
          expect(user.home_project.packages).to be_empty
        end
      end
    end
  end

  describe 'GET #show' do
    context 'with a valid package' do
      before do
        get :show, params: { project: user.home_project, package: source_package.name }
      end

      it 'assigns @package' do
        expect(assigns(:package)).to eq(source_package)
      end
    end

    # FIXME: This is not how the backend behaves today, it validates servce files. You can't re-generate the cassette of this spec
    context 'with a package that has a broken service' do
      before do
        login user
        get :show, params: { project: user.home_project, package: broken_service_package.name }
      end

      it { expect(flash[:error]).to include('Files could not be expanded:') }
      it { expect(assigns(:more_info)).to include('service daemon error:') }
    end

    context 'revision handling' do
      let(:package_with_revisions) do
        create(:package_with_revisions, name: 'rev_package', revision_count: 3, project: user.home_project)
      end

      after do
        # Cleanup: otherwhise older revisions stay in backend and influence other tests, and test re-runs
        package_with_revisions.destroy
      end

      context "with a 'rev' parameter with existent revision" do
        before do
          get :show, params: { project: user.home_project, package: package_with_revisions, rev: 2 }
        end

        it { expect(assigns(:revision)).to eq('2') }
        it { expect(response).to have_http_status(:success) }
      end

      context "with a 'rev' parameter with non-existent revision" do
        before do
          get :show, params: { project: user.home_project, package: package_with_revisions, rev: 4 }
        end

        it { expect(flash[:error]).to eq('No such revision: 4') }
        it { expect(response).to redirect_to(package_show_path(project: user.home_project, package: package_with_revisions)) }
      end
    end
  end

  describe 'GET #revisions' do
    let(:project) { create(:project, maintainer: user, name: 'some_dev_project123') }
    let(:package) { create(:package_with_revisions, name: 'package_with_one_revision', revision_count: 25, project: project) }
    let(:elided_package_name) { 'package_w...revision' }

    before do
      login(user)
    end

    context 'with source access' do
      before do
        get :revisions, params: { project: project, package: package }
      end

      after do
        # Delete revisions that got created in the backend
        package.destroy
      end

      context 'when not passing the rev parameter' do
        let(:package_with_revisions) { create(:package_with_revisions, name: "package_with_#{revision_count}_revisions", revision_count: revision_count, project: project) }
        let(:revision_count) { 25 }

        before do
          get :revisions, params: { project: project, package: package_with_revisions }
        end

        after do
          # Delete revisions that got created in the backend
          package_with_revisions.destroy
        end

        it 'returns revisions with the default pagination' do
          expect(assigns(:revisions)).to match_array((6..revision_count).to_a.reverse.map { |n| include('rev' => n.to_s) })
        end

        context 'and passing the show_all parameter' do
          before do
            get :revisions, params: { project: project, package: package_with_revisions, show_all: 1 }
          end

          it 'returns revisions without pagination' do
            expect(assigns(:revisions)).to match_array((1..revision_count).to_a.reverse.map { |n| include('rev' => n.to_s) })
          end
        end

        context 'and passing the page parameter' do
          before do
            get :revisions, params: { project: project, package: package_with_revisions, page: 2 }
          end

          it "returns the paginated revisions for the page parameter's value" do
            expect(assigns(:revisions)).to match_array((1..5).to_a.reverse.map { |n| include('rev' => n.to_s) })
          end
        end
      end

      context 'when passing the rev parameter' do
        before do
          get :revisions, params: { project: project, package: package, rev: param_rev }
        end

        let(:param_rev) { 23 }

        it "returns revisions up to rev parameter's value with the default pagination" do
          expect(assigns(:revisions)).to match_array((4..param_rev).to_a.reverse.map { |n| include('rev' => n.to_s) })
        end

        context 'and passing the show_all parameter' do
          before do
            get :revisions, params: { project: project, package: package, rev: param_rev, show_all: 1 }
          end

          it "returns revisions up to rev parameter's value without pagination" do
            expect(assigns(:revisions)).to match_array((1..param_rev).to_a.reverse.map { |n| include('rev' => n.to_s) })
          end
        end

        context 'and passing the page parameter' do
          before do
            get :revisions, params: { project: project, package: package, rev: param_rev, page: 2 }
          end

          it "returns the paginated revisions for the page parameter's value" do
            expect(assigns(:revisions)).to match_array((1..3).to_a.reverse.map { |n| include('rev' => n.to_s) })
          end
        end
      end
    end
  end

  describe 'GET #rdiff' do
    context 'when no difference in sources diff is empty' do
      before do
        login user
        get :rdiff, params: { project: source_project, package: package, oproject: source_project, opackage: package }
      end

      it { expect(assigns[:filenames]).to be_empty }
    end

    context 'when an empty revision is provided' do
      before do
        login user
        get :rdiff, params: { project: source_project, package: package, rev: '' }
      end

      it { expect(flash[:error]).to eq('Error getting diff: revision is empty') }
      it { is_expected.to redirect_to(package_show_path(project: source_project, package: package)) }
    end

    context 'with diff truncation' do
      let(:diff_header_size) { 4 }
      let(:ascii_file_size) { 11_000 }
      # Taken from package_with_binary_diff factory files (bigfile_archive.tar.gz and bigfile_archive_2.tar.gz)
      let(:binary_file_size) { 30_000 }
      let(:binary_file_changed_size) { 13_000 }
      # TODO: check if this value, the default diff size, is correct
      let(:default_diff_size) { 199 }
      let(:package_ascii_file) do
        create(:package_with_file, name: 'diff-truncation-test-1', project: source_project, file_content: "a\n" * ascii_file_size)
      end
      let(:package_binary_file) { create(:package_with_binary_diff, name: 'diff-truncation-test-2', project: source_project) }

      context 'full diff requested' do
        it 'does not show a hint' do
          login user
          get :rdiff, params: { project: source_project, package: package_ascii_file, full_diff: true, rev: 2 }
          expect(assigns(:not_full_diff)).to be_falsy
        end

        context 'for ASCII files' do
          before do
            login user
            get :rdiff, params: { project: source_project, package: package_ascii_file, full_diff: true, rev: 2 }
          end

          it 'shows the complete diff' do
            diff_size = assigns(:files)['somefile.txt']['diff']['_content'].split.size
            expect(diff_size).to eq(ascii_file_size + diff_header_size)
          end
        end

        context 'for archives' do
          before do
            login user
            get :rdiff, params: { project: source_project, package: package_binary_file, full_diff: true }
          end

          it 'shows the complete diff' do
            diff = assigns(:files)['bigfile_archive.tar.gz/bigfile.txt']['diff']['_content'].split("\n")
            expect(diff).to eq(['@@ -1,6 +1,6 @@', '-a', '-a', '-a', '-a', '-a', '-a', '+b', '+b', '+b', '+b', '+b', '+b'])
          end
        end
      end

      context 'full diff not requested' do
        it 'shows a hint' do
          login user
          get :rdiff, params: { project: source_project, package: package_ascii_file, rev: 2 }
          expect(assigns(:not_full_diff)).to be_truthy
        end

        context 'for ASCII files' do
          before do
            login user
            get :rdiff, params: { project: source_project, package: package_ascii_file, rev: 2 }
          end

          it 'shows the truncated diff' do
            diff_size = assigns(:files)['somefile.txt']['diff']['_content'].split.size
            expect(diff_size).to eq(default_diff_size + diff_header_size)
          end
        end

        context 'for archives' do
          before do
            login user
            get :rdiff, params: { project: source_project, package: package_binary_file }
          end

          it 'shows the truncated diff' do
            diff = assigns(:files)['bigfile_archive.tar.gz/bigfile.txt']['diff']['_content'].split("\n")
            expect(diff).to eq(['@@ -1,6 +1,6 @@', '-a', '-a', '-a', '-a', '-a', '-a', '+b', '+b', '+b', '+b', '+b', '+b'])
          end
        end
      end
    end
  end

  # FIXME: This should be feature specs
  describe 'GET #statistics' do
    let!(:repository) { create(:repository, name: 'statistics', project: source_project, architectures: ['i586']) }

    before do
      login(user)

      # Save the repository in backend
      source_project.store
    end

    context 'when backend returns statistics' do
      render_views

      before do
        allow(Backend::Api::BuildResults::Status).to receive(:statistics)
          .with(source_project.name, source_package.name, repository.name, 'i586')
          .and_return('<buildstatistics><disk><usage><size unit="M">30</size></usage></disk></buildstatistics>')

        get :statistics, params: { project: source_project.name, package: source_package.name, arch: 'i586', repository: repository.name }
      end

      it { expect(assigns(:statistics).disk).to have_attributes(size: '30', unit: 'M', io_requests: nil, io_sectors: nil) }
      it { expect(response).to have_http_status(:success) }
    end

    context 'when backend does not return statistics' do
      let(:get_statistics) { get :statistics, params: { project: source_project.name, package: source_package.name, arch: 'i586', repository: repository.name } }

      it { expect(assigns(:statistics)).to be_nil }
    end

    context 'when backend raises an exception' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:statistics)
          .with(source_project.name, source_package.name, repository.name, 'i586')
          .and_raise(Backend::NotFoundError)
      end

      let(:get_statistics) { get :statistics, params: { project: source_project.name, package: source_package.name, arch: 'i586', repository: repository.name } }

      it { expect(assigns(:statistics)).to be_nil }
    end

    context 'the project is an scmsync project' do
      let(:scmsync_project) { create(:project, name: 'lorem', scmsync: 'https://github.com/example/scmsync-project.git') }

      before do
        get :statistics, params: { project: scmsync_project.name, package: source_package.name, arch: 'i586', repository: repository.name }
      end

      it { expect(flash[:error]).to eq('The project lorem is configured through scmsync. This is not supported by the OBS frontend') }
      it { expect(response).to redirect_to(project_show_path(scmsync_project)) }
    end
  end

  describe '#rpmlint_result' do
    let(:fake_build_result) do
      <<-XML
        <resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
          <result project="home:tom" repository="openSUSE_Tumbleweed" arch="i586" code="building" state="building">
            <status package="my_package" code="excluded" />
          </result>
          <result project="home:tom" repository="openSUSE_Leap_42.1" arch="armv7l" code="unknown" state="unknown" />
          <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="building" state="building">
            <status package="my_package" code="signing" />
          </result>
          <result project="home:tom" repository="images" arch="x86_64" code="building" state="building">
            <status package="my_package" code="signing" />
          </result>
        </resultlist>
      XML
    end

    before do
      allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_build_result)
      post :rpmlint_result, xhr: true, params: { package: source_package, project: source_project }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(assigns(:repo_list)).to include(['openSUSE_Leap_42.1', 'openSUSE_Leap_42_1']) }
    it { expect(assigns(:repo_list)).not_to include(%w[images images]) }
    it { expect(assigns(:repo_list)).not_to include(%w[openSUSE_Tumbleweed openSUSE_Tumbleweed]) }
    it { expect(assigns(:repo_arch_hash)['openSUSE_Leap_42_1']).to include('x86_64') }
    it { expect(assigns(:repo_arch_hash)['openSUSE_Leap_42_1']).not_to include('armv7l') }
  end

  describe 'GET #rpmlint_log' do
    describe 'when no rpmlint log is available' do
      render_views

      subject do
        get :rpmlint_log, params: { project: source_project, package: source_package, repository: repo_for_source_project.name, architecture: 'i586' }
      end

      it { is_expected.to have_http_status(:success) }
      it { expect(subject.body).to eq('No rpmlint log') }
    end

    describe 'when there is a rpmlint log' do
      subject do
        get :rpmlint_log, params: { project: source_project, package: source_package, repository: repo_for_source_project.name, architecture: 'i586' }
      end

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:rpmlint_log)
          .with(source_project.name, source_package.name, repo_for_source_project.name, 'i586')
          .and_return('test_package.i586: W: description-shorter-than-summary\ntest_package.src: W: description-shorter-than-summary')
      end

      it { is_expected.to have_http_status(:success) }
      it { is_expected.to render_template('webui/package/_rpmlint_log') }
    end
  end

  describe 'POST #create' do
    let(:package_name) { 'new-package' }
    let(:my_user) { user }
    let(:post_params) do
      { project: source_project,
        package: { name: package_name, title: 'package foo', description: 'awesome package foo' } }
    end

    context 'Package#save failed' do
      before do
        login(my_user)
        post :create, params: post_params.merge(package: { name: package_name, title: 'a' * 251 })
      end

      it { expect(response).to redirect_to(project_show_path(source_project)) }
      it { expect(flash[:error]).to eq('Failed to create package: Title is too long (maximum is 250 characters)') }
    end

    context 'package creation' do
      before do
        login(my_user)
        post :create, params: post_params
      end

      context 'valid package name' do
        it { expect(response).to redirect_to(package_show_path(source_project, package_name)) }
        it { expect(flash[:success]).to eq("Package 'new-package' was created successfully") }
        it { expect(Package.find_by(name: package_name).flags).to be_empty }
      end

      context 'valid package with source_protection enabled' do
        let(:post_params) do
          { project: source_project, source_protection: 'foo', disable_publishing: 'bar',
            package: { name: package_name, title: 'package foo', description: 'awesome package foo' } }
        end

        it { expect(Package.find_by(name: package_name).flags).to include(Flag.find_by_flag('sourceaccess')) }
        it { expect(Package.find_by(name: package_name).flags).to include(Flag.find_by_flag('publish')) }
      end

      context 'invalid package name' do
        let(:package_name) { 'A' * 250 }

        it { expect(response).to redirect_to(project_show_path(source_project)) }
        it { expect(flash[:error]).to match('Failed to create package: Name is too long (maximum is 200 characters), Name is illegal') }
      end

      context 'package already exist' do
        let(:package_name) { package.name }

        it { expect(response).to redirect_to(project_show_path(source_project)) }
        it { expect(flash[:error]).to start_with("Failed to create package: Project `#{source_project.name}` already has a package with the name `#{package_name}`") }
      end

      context 'not allowed to create package in' do
        let(:package_name) { 'foo' }
        let(:my_user) { create(:confirmed_user, login: 'another_user') }

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).to eq('Sorry, you are not authorized to create this package.') }
      end
    end
  end

  describe 'GET #edit' do
    context 'when the user is authorized to edit the package' do
      before do
        login(user)
        get :edit, xhr: true, params: { project: source_project, package: source_package }, format: :js
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns[:project]).to eql(source_project) }
      it { expect(assigns[:package]).to eql(source_package) }
    end

    context 'when the user is NOT authorized to edit the package' do
      let(:admins_home_project) { admin.home_project }
      let(:package_from_admin) do
        create(:package, name: 'admins_package', project: admins_home_project)
      end

      before do
        login(user)
        get :edit, params: { project: admins_home_project, package: package_from_admin }
      end

      it { expect(response).to redirect_to(root_path) }
    end
  end

  describe 'PATCH #update' do
    let(:package_params) do
      {
        title: 'Updated title',
        url: 'https://updated.url',
        description: 'Updated description.'
      }
    end

    before do
      login(user)
      patch :update,
            params: {
              project: source_project,
              package_details: package_params,
              package: source_package.name
            },
            format: :js
    end

    context 'when the user is authorized to change the package' do
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:package).title).to eql(package_params[:title]) }
      it { expect(assigns(:package).url).to eql(package_params[:url]) }
      it { expect(assigns(:package).description).to eql(package_params[:description]) }
    end

    context 'when the user is NOT authorized to change the package' do
      let(:source_project) { admin.home_project }
      let(:source_package) { create(:package, name: 'admins_package', project: source_project) }

      it { expect(response).to have_http_status(:forbidden) }
    end
  end
end
