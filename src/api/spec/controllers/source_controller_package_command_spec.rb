RSpec.describe SourceController, '#package_command' do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

  before do
    login user
    request.headers['ACCEPT'] = 'text/xml'
  end

  describe 'POST #unlock' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'unlock', comment: 'hello unlocked world' } }

    let(:project) { user.home_project }
    let(:package) { create(:package, name: 'hans', project: project) }

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
    subject { post :package_command, params: { project: project, package: package, cmd: 'instantiate' } }

    let(:project) { create(:project, name: 'My:Linux', maintainer: user) }
    let(:update_project) do
      update_project = create(:project, name: 'My:Linux:Update', maintainer: user)
      create(:update_project_attrib, project: project, update_project: update_project)
      update_project
    end
    let(:package) { create(:package, project: project) }

    context 'with a remote package' do
      before do
        # Mock a package coming over a remote project-link
        # https://github.com/openSUSE/open-build-service/wiki/Links#instantiating-returns-nil
        allow(Package).to receive(:get_by_project_and_name).and_return(nil)
      end

      it 'renders remote_project error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('remote_project')
      end
    end

    context 'when the package already exists' do
      render_views

      it 'renders an error' do
        expect(Xmlhash.parse(subject.body)['summary']).to eq('package is already instantiated here')
      end
    end
  end

  describe 'POST #undelete' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'undelete' } }

    let(:project) { user.home_project }
    let(:package) { create(:package, name: 'hans', project: project) }

    context 'when the package is deleted', :vcr do
      before do
        package.destroy
      end

      it 'restores the package' do
        expect { subject }.to change { project.packages.count }.from(0).to(1)
      end
    end

    context 'when the package exists' do
      it 'renders package_exists error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('package_exists')
      end
    end

    context 'when the user is not allowed to create package in project' do
      let(:project) { create(:project) }

      render_views

      it 'renders create_package_not_authorized error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('cmd_execution_no_permission')
        expect(Xmlhash.parse(response.body)['summary']).to eq("no permission to modify package hans in project #{project.name}")
      end
    end

    context 'when a user without admin role sets time' do
      subject { post :package_command, params: { project: project, package: 'hans', cmd: 'undelete', time: '12345', format: :xml } }

      render_views

      it 'renders cmd_execution_no_permission error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('cmd_execution_no_permission')
        expect(Xmlhash.parse(response.body)['summary']).to eq('Only administrators are allowed to set the time')
      end
    end
  end

  describe 'POST #rebuild' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'rebuild', format: :xml } }

    let(:project) { user.home_project }
    let(:package) { create(:package, name: 'hans', project: project) }

    it { expect(response).to have_http_status(:ok) }

    context 'with a package from a remote project link' do
      before do
        allow(Package).to receive(:get_by_project_and_name).and_return(nil)
      end

      context 'that does not exist on the backend' do
        before do
          allow(Package).to receive(:exists_on_backend?).and_return(false)
        end

        it 'renders unknown_package error' do
          expect(subject.headers['X-Opensuse-Errorcode']).to eq('unknown_package')
        end
      end

      context 'that exists on the backend' do
        before do
          allow(Package).to receive(:exists_on_backend?).and_return(true)
        end

        it 'rebuilds' do
          skip('this is broken since bba7aebd25642b8bca56e09c82b7450aa916e36f as it sets @project to nil')
        end
      end
    end

    context 'with an unknown package' do
      let(:package) { 'franz' }

      it 'renders unknown_package error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('unknown_package')
      end
    end

    context 'with an unknown repository' do
      subject { post :package_command, params: { project: project, package: package, repo: 'hans', cmd: 'rebuild', format: :xml } }

      it 'renders unknown_repository error' do
        expect(subject.headers['X-Opensuse-Errorcode']).to eq('unknown_repository')
      end
    end
  end

  describe 'POST #copy', :vcr do
    subject { post :package_command, params: { project: project, package: package, cmd: 'copy', oproject: source_project, opackage: source_package } }

    let(:project) { user.home_project }
    let!(:source_project) { create(:project, name: 'peter') }
    let!(:source_package) do
      source_package_with_flags = create(:package, project: source_project, name: 'paul', title: 'lala')
      create(:debuginfo_flag, package: source_package_with_flags)
      create(:publish_flag, package: source_package_with_flags)
      source_package_with_flags.store
      source_package_with_flags
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

      it 'copies the package attributes' do
        subject
        expect(project.packages.last.title).to eq('lala')
      end
    end
  end

  # rubocop:disable RSpec/RepeatedExampleGroupBody
  # rubocop:disable RSpec/RepeatedExample
  describe 'POST #release' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'release' } }

    context 'with target_project parameter' do
      it 'raises MissingParameterError if params[:target_repository].blank? || params[:repository].blank?' do
        skip('to be tested')
      end

      it 'does whatever _package_command_release_manual_target does' do
        skip('to be tested')
      end
    end

    context 'without target_project parameter' do
      it 'does whatever verify_release_targets does' do
        skip('to be tested')
      end

      it 'does whatever release_package does' do
        skip('to be tested')
      end
    end
  end

  describe 'POST #branch' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'branch' } }

    it 'branches the package' do
      skip('to be tested')
    end

    context 'with dryrun' do
      it 'does nothing' do
        skip('to be tested')
      end
    end

    context 'without permission to create target project' do
      it 'CreateProjectNoPermission' do
        skip('to be tested')
      end
    end

    context 'without permission to create the target package' do
      it 'CmdExecutionNoPermission' do
        skip('to be tested')
      end
    end
  end

  describe 'POST #package_command_fork' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'fork' } }

    it 'forks the package' do
      skip('to be tested')
    end

    context 'without scmsync param' do
      it 'MissingParameterError' do
        skip('to be tested')
      end
    end
  end

  describe 'POST #set_flag' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'set_flag' } }

    it 'adds the flag'

    context 'without flag param' do
      it 'MissingParameterError' do
        skip('to be tested')
      end
    end

    context 'without status param' do
      it 'MissingParameterError' do
        skip('to be tested')
      end
    end
  end

  describe 'POST #remove_flag' do
    subject { post :package_command, params: { project: project, package: package, cmd: 'remove_flag' } }

    it 'removes the flag' do
      skip('to be tested')
    end

    context 'without flag param' do
      it 'MissingParameterError' do
        skip('to be tested')
      end
    end
  end
  # rubocop:enable RSpec/RepeatedExampleGroupBody
  # rubocop:enable RSpec/RepeatedExample
end
