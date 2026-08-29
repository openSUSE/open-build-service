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

  describe 'POST #unlock' do
    subject { post :unlock, params: { project: project.name, package: package.name, cmd: 'unlock', comment: 'hello unlocked world' } }

    let(:project) { user.home_project }
    let(:package) { create(:package, name: 'hans', project: project) }
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    context 'without enabled lock flag' do
      it 'renders not_locked error' do
        expect(subject.header['X-Opensuse-Errorcode']).to eq('not_locked')
      end
    end

    context 'with enabled lock flag' do
      before do
        package.flags.create(flag: 'lock', status: 'enable')
      end

      it 'deletes the flag' do
        expect { subject }.to change { package.flags.where(flag: :lock, status: :enable).count }.from(1).to(0)
      end
    end
  end

  # FIXME: The happy path is only tested in the giant minitest MaintenanceTests.
  describe 'POST #instantiate' do
    subject { post :instantiate, params: { project: project, package: package, cmd: 'instantiate' } }

    let(:project) { create(:project, name: 'My:Linux', maintainer: user) }
    let(:update_project) do
      update_project = create(:project, name: 'My:Linux:Update', maintainer: user)
      create(:update_project_attrib, project: project, update_project: update_project)
      update_project
    end
    let(:package) { create(:package, project: project) }
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    context 'when the package already exists' do
      render_views

      it 'renders an error' do
        expect(Xmlhash.parse(subject.body)['summary']).to eq('package is already instantiated here')
      end
    end
  end

  describe 'POST #copy' do
    subject { post :copy, params: { project: project, package: package, cmd: 'copy', oproject: source_project, opackage: source_package } }

    let(:project) { user.home_project }
    let!(:source_project) { create(:project, name: 'peter') }
    let!(:source_package) do
      source_package_with_flags = create(:package, project: source_project, name: 'paul', title: 'lala')
      create(:debuginfo_flag, package: source_package_with_flags)
      create(:publish_flag, package: source_package_with_flags)
      source_package_with_flags.store
      source_package_with_flags
    end
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    context 'with a package' do
      let!(:package) do
        package_with_flags = create(:package, name: 'hans', project: project)
        create(:useforbuild_flag, package: package_with_flags)
        package_with_flags.store
        package_with_flags
      end

      it 'does not create a new package' do
        expect { subject }.not_to change(Package, :count)
      end

      it 'does not change the package flags' do
        expect { subject }.not_to change(Flag, :count)
      end

      it 'does not change the package attributes' do
        expect { subject }.not_to change(package, :title)
      end
    end

    context 'without a package' do
      let(:package) { 'franz' }

      it 'creates a new package' do
        expect { subject }.to change(Package, :count).from(1).to(2)
      end

      it 'copies the flags' do
        expect { subject }.to change(Flag, :count).from(2).to(4)
      end
    end
  end

  describe 'POST #branch' do
    subject { post :branch, params: { project: project, package: package, cmd: 'branch' } }

    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    xit 'branches the package'

    context 'with dryrun' do
      xit 'does nothing'
    end

    context 'without permission to create target project' do
      xit 'CreateProjectNoPermission'
    end

    context 'without permission to create the target package' do
      xit 'CmdExecutionNoPermission'
    end
  end

  describe 'POST #fork' do
    subject { post :fork, params: { project: project, package: package, cmd: 'fork' } }

    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    xit 'forks the package'

    context 'without scmsync param' do
      xit 'MissingParameterError'
    end
  end

  describe 'POST #set_flag' do
    subject { post :set_flag, params: { project: project, package: package, cmd: 'set_flag' } }

    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    context 'without flag param' do
      xit 'MissingParameterError'
    end

    context 'without status param' do
      xit 'MissingParameterError'
    end
  end

  describe 'POST #remove_flag' do
    subject { post :remove_flag, params: { project: project, package: package, cmd: 'remove_flag' } }

    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

    before do
      login user
      request.headers['ACCEPT'] = 'text/xml'
    end

    xit 'removes the flag'

    context 'without flag param' do
      xit 'MissingParameterError'
    end
  end
end
