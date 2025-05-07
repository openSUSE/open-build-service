RSpec.describe SourcePackageCommandController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  describe 'POST #release' do
    subject { post :release, params: { cmd: 'release', project: project, package: package }, format: :xml }

    let(:user) { create(:confirmed_user, login: 'peter') }
    let(:target_project) do
      released_project = create(:project, name: 'franz_released', maintainer: user)
      create(:repository, project: released_project, name: 'standard', architectures: ['x86_64'])

      released_project.store
      released_project
    end

    let(:project) do
      source_project = create(:project, name: 'franz', maintainer: user)
      create(:repository, project: source_project, name: 'standard', architectures: ['x86_64'])
      create(:release_target, repository: source_project.repositories.first, target_repository: target_project.repositories.first, trigger: 'manual')

      source_project.store
      source_project
    end
    let(:package) { create(:package, name: 'hans', project: project) }

    before do
      login user
    end

    it { expect(subject).to have_http_status(:ok) }
    it { expect { subject }.to change(Package, :count).from(0).to(2) }

    context 'without project' do
      let(:project) { 'franz' }
      let(:package) { 'hans' }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
    end

    context 'without package' do
      let(:package) { 'hans' }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end

    context 'without release targets' do
      let(:project) { create(:project, maintainer: user) }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('no_matching_release_target') }
    end

    context 'with target parameters' do
      subject do
        post :release,
             params: { cmd: 'release',
                       package: package,
                       project: project,
                       target_project: target_project.name,
                       target_repository: target_project.repositories.first.name,
                       repository: project.repositories.first.name }, format: :xml
      end

      it { expect(subject).to have_http_status(:ok) }
      it { expect { subject }.to change(Package, :count).from(0).to(2) }
    end

    context 'with scmsync project' do
      let(:project) do
        source_project = create(:project, name: 'franz', scmsync: 'https://github.com/hennevogel/scmsync-project.git', maintainer: user)
        create(:repository, project: source_project, name: 'standard', architectures: ['x86_64'])
        create(:release_target, repository: source_project.repositories.first, target_repository: target_project.repositories.first, trigger: 'manual')

        source_project.store
        source_project
      end

      let(:package) { 'hans' }
      let(:package_xml) do
        <<-HEREDOC
          <package name="hans" project="#{project.name}">
            <title>hans</title>
            <description>franz</description>
          </package>
        HEREDOC
      end

      before do
        allow(Backend::Api::Sources::Package).to receive(:meta).and_return(package_xml)
      end

      it { expect(subject).to have_http_status(:ok) }
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
          cmd: 'diff', package: "#{multibuild_package.name}:one", project: multibuild_project, target_project: project
        }
      end

      it { expect(flash[:error]).to eq("invalid package name '#{multibuild_package.name}:one' (invalid_package_name)") }
      it { expect(response).to have_http_status(:found) }
    end
  end

  describe 'POST #undelete' do
    context 'without permissions to undelete the package' do
      let(:package) { create(:package) }

      before do
        package.destroy
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
        package.destroy
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
        package.destroy
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
        package.destroy
        login admin

        post :undelete, params: {
          cmd: 'undelete', project: package.project, package: package, time: future, format: :xml
        }
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
