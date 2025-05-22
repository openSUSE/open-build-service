RSpec.describe SourcePackageController do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let!(:project) { create(:project_with_package, name: 'hans', package_name: 'franz', maintainer: user, commit_user: user) }
  let(:package) { project.packages.first }

  describe 'GET #show' do
    subject { get :show, params: { project: 'hans', package: 'franz' } }

    before do
      login user
    end

    it { expect(subject).to have_http_status(:success) }

    context 'when the project does not exist' do
      before do
        project.destroy
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
    end

    context 'when the package does not exist' do
      before do
        package.destroy
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end

    context 'with deleted parameter set' do
      subject { get :show, params: { project: 'hans', package: 'franz', deleted: 1 } }

      let(:revisions) { file_fixture('project-or-package-revisons.xml').read }

      context 'when the project is deleted' do
        before do
          allow(Backend::Api::Sources::Project).to receive(:meta).and_return(project.to_axml)
          project.destroy
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the package is deleted' do
        before do
          allow(Backend::Api::Sources::Package).to receive(:meta).and_return(package.to_axml)
          package.destroy
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the project and the package are deleted' do
        before do
          allow(Backend::Api::Sources::Project).to receive(:meta).and_return(project.to_axml)
          allow(Backend::Api::Sources::Package).to receive(:meta).and_return(package.to_axml)
          package.destroy
          project.destroy
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the project was access protected' do
        let!(:flag) { create(:access_flag, project: project, status: :disable) }

        before do
          allow(Backend::Api::Sources::Project).to receive(:meta).and_return(project.to_axml)
          project.destroy
        end

        it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
      end

      context 'when the package was sourceaccess protected' do
        let!(:flag) { create(:sourceaccess_flag, package: package, status: :disable) }

        before do
          allow(Backend::Api::Sources::Package).to receive(:meta).and_return(package.to_axml)
          package.destroy
        end

        it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('source_access_no_permission') }
      end
    end
  end
end
