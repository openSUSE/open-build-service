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
        # rubocop:disable Rails/SkipsModelValidations
        project.update_columns(scmsync: 'https://github.com/hennevogel/scmsync-project.git')
        # rubocop:enable Rails/SkipsModelValidations
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
end
