RSpec.describe SourcePackageCommandController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  describe 'POST #release' do
    subject { post :release, params: { cmd: 'release', project: 'franz', package: 'hans' }, format: :xml }

    let(:user) { create(:confirmed_user, login: 'peter') }
    let!(:project) do
      project = create(:project, name: 'franz', maintainer: user)
      repo = create(:repository, project: project, name: 'standard', architectures: ['x86_64'])
      create(:release_target, repository: repo, target_repository: target_repository, trigger: 'manual')
      project
    end
    let(:target_repository) { create(:repository, project: target_project, name: 'standard', architectures: ['x86_64']) }
    let(:target_project) { create(:project, name: 'franz_released', maintainer: user) }
    let!(:package) { create(:package, name: 'hans', project: project) }

    before do
      login user
    end

    it { expect { subject }.to change(Package, :count).from(1).to(2) }

    context 'without project' do
      before do
        user.run_as { project.destroy }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
    end

    context 'without package' do
      before do
        user.run_as { package.destroy }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end

    context 'without release targets' do
      before do
        user.run_as { project.repositories.first.release_targets.first.destroy }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('no_matching_release_target') }
    end

    context 'with target parameters' do
      subject do
        post :release,
             params: { cmd: 'release',
                       package: package,
                       project: project,
                       target_project: target_project,
                       target_repository: target_repository,
                       repository: project.repositories.first }, format: :xml
      end

      it { expect { subject }.to change(Package, :count).from(1).to(2) }
    end

    context 'with scmsync project' do
      let(:package_xml) do
        <<-HEREDOC
          <package name="hans" project="#{project.name}">
            <title>hans</title>
            <description>franz</description>
          </package>
        HEREDOC
      end

      before do
        user.run_as { project.packages.first.destroy }
        # rubocop:disable-next Rails/SkipsModelValidations
        project.update_columns(scmsync: 'https://github.com/hennevogel/scmsync-project.git')
        allow(Backend::Api::Sources::Package).to receive(:meta).and_return(package_xml)
      end

      it { expect { subject }.to change(Package, :count).from(0).to(1) }
    end
  end

  describe 'POST #diff' do
    let(:multibuild_package) { create(:package, name: 'multibuild') }
    let(:multibuild_project) { multibuild_package.project }
    let(:repository) { create(:repository) }
    let(:target_repository) { create(:repository) }

    before do
      multibuild_project.repositories << repository
      project.repositories << target_repository
      login user
    end

    context "with 'diff' command for a multibuild package" do
      before do
        post :diff, params: {
          cmd: 'diff', project: multibuild_project, package: "#{multibuild_package.name}:one", format: :xml
        }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end
  end

  describe 'POST #undelete' do
    context 'without permissions to undelete the package' do
      let(:package) { create(:package) }

      before do
        user.run_as { package.destroy }
        login user

        post :undelete, params: {
          cmd: 'undelete', project: package.project, package: package, format: :xml
        }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('create_package_not_authorized') }
    end

    context 'with permissions to undelete the package' do
      let(:package) { create(:package, name: 'some_package', project: project) }

      before do
        user.run_as { package.destroy }
        login user

        post :undelete, params: {
          cmd: 'undelete', project: package.project, package: package, format: :xml
        }
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'without permissions to set the time' do
      let(:package) { create(:package, project: project) }

      before do
        user.run_as { package.destroy }
        login user

        post :undelete, params: {
          cmd: 'undelete', project: package.project, package: package, time: 1.month.ago, format: :xml
        }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('cmd_execution_no_permission') }
    end

    context 'with permissions to set the time' do
      let(:admin) { create(:admin_user, login: 'admin') }
      let(:package) { create(:package, name: 'some_package', project: project) }
      let(:future) { 4_803_029_439 }

      before do
        admin.run_as { package.destroy }
        login admin

        post :undelete, params: {
          cmd: 'undelete', project: package.project, package: package, time: future, format: :xml
        }
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe 'POST #rebuild' do
    let(:project) { create(:project_with_repository, name: 'foo', maintainer: user) }
    let(:package) { create(:package, name: 'bar', project: project) }
    let(:repository) { project.repositories.first }
    let(:rebuild_params) { { repository: repository.name, arch: nil } }

    before do
      login user
    end

    context 'with an unknown repository' do
      subject { post :rebuild, params: { cmd: 'rebuild', project: project.name, package: package.name, repo: 'missing', format: :xml } }

      before do
        allow(Backend::Api::Sources::Package).to receive(:rebuild)
      end

      it 'returns unknown_repository without triggering a rebuild' do
        subject

        expect(response.headers['X-Opensuse-Errorcode']).to eql('unknown_repository')
        expect(Backend::Api::Sources::Package).not_to have_received(:rebuild)
      end
    end

    context 'with a known repository' do
      subject { post :rebuild, params: { cmd: 'rebuild', project: project.name, package: package.name, repo: repository.name, format: :xml } }

      before do
        allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")
      end

      it { expect(subject).to have_http_status(:ok) }

      it 'triggers the rebuild for that repository' do
        subject

        expect(Backend::Api::Sources::Package).to have_received(:rebuild).with(project.name, package.name, rebuild_params)
      end
    end
  end

  describe 'POST #copy' do
    subject do
      post :copy, params: { cmd: 'copy', project: project, package: 'hans',
                            oproject: origin_project, opackage: origin_package_name }, format: :xml
    end

    let(:origin_project) { create(:project, name: 'origin_project', maintainer: user) }
    let(:backend_response) { instance_double(Net::HTTPResponse, body: '<status code="ok" />') }

    before do
      create(:package, name: 'hans', project: project)
      allow(backend_response).to receive(:fetch).and_return('text/xml')
      allow(Backend::Connection).to receive(:post).and_return(backend_response)
      allow(Backend::Api::Sources::Package).to receive(:files).and_return('<directory/>')
      login user
    end

    context 'with an origin package that exists' do
      let(:origin_package_name) { 'franz' }

      before do
        create(:package, name: 'franz', project: origin_project)
      end

      it { expect(subject).to have_http_status(:ok) }
    end

    context 'with an origin package that does not exist' do
      let(:origin_package_name) { 'franz' }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end

    context 'with _project as the origin package' do
      let(:origin_package_name) { '_project' }

      it { expect(subject).to have_http_status(:ok) }

      it 'copies from the _project of the origin project' do
        subject

        expect(Backend::Connection).to have_received(:post).with(a_string_including('oproject=origin_project&opackage=_project'), any_args)
      end
    end

    context 'with a _pattern package as the origin package' do
      let(:origin_package_name) { '_pattern' }

      before do
        create(:package, name: '_pattern', project: origin_project)
      end

      it { expect(subject).to have_http_status(:ok) }

      it 'copies from the _pattern of the origin project' do
        subject

        expect(Backend::Connection).to have_received(:post).with(a_string_including('oproject=origin_project&opackage=_pattern'), any_args)
      end
    end

    context 'with _project of an origin project without source access' do
      let(:origin_project) do
        origin_project = create(:project, name: 'origin_project')
        create(:sourceaccess_flag, project: origin_project)
        origin_project.reload
      end
      let(:origin_package_name) { '_project' }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('source_access_no_permission') }
    end
  end

  describe 'POST #updatepatchinfo' do
    subject { post :updatepatchinfo, params: { cmd: 'updatepatchinfo', project: project, package: 'hans' }, format: :xml }

    before do
      login user
    end

    context 'with a package that only exists in the backend of an scmsync project' do
      before do
        # rubocop:disable-next Rails/SkipsModelValidations
        project.update_columns(scmsync: 'https://github.com/example/scmsync-project.git')
      end

      it { expect(subject).to have_http_status(:forbidden) }
      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('cmd_execution_no_permission') }
    end

    context 'with a package that does not exist in a regular project' do
      it { expect(subject).to have_http_status(:not_found) }
      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end
  end
end
