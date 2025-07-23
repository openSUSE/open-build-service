RSpec.describe SourcePackageController, :vcr do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { create(:project, name: 'hans', maintainer: user) }
  let!(:package) { create(:package_with_file, project: project, name: 'franz') }

  describe 'GET #show' do
    subject { get :show, params: { project: 'hans', package: 'franz' } }

    before do
      login user
    end

    it { expect(subject).to have_http_status(:success) }

    context 'when the project does not exist' do
      before do
        user.run_as { project.destroy }
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
    end

    context 'when the package does not exist' do
      before do
        package.destroy
      end

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_package') }
    end

    # If you change things in this context and want to re-record cassettes you will have to reset your
    # backend every time you run an example.
    context 'with deleted parameter set' do
      subject { get :show, params: { project: 'hans', package: 'franz', deleted: 1 } }

      let(:revisions) { file_fixture('project-or-package-revisons.xml').read }

      context 'when the project is deleted' do
        before do
          user.run_as { project.destroy }
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the package is deleted' do
        before do
          user.run_as { package.destroy }
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the project and the package are deleted', skip: 'FIXME: https://github.com/openSUSE/open-build-service/issues/17958' do
        before do
          user.run_as do
            package.destroy
            project.destroy
          end
        end

        it { expect(subject).to have_http_status(:success) }
      end

      context 'when the project was access protected' do
        let(:project) { create(:forbidden_project, name: 'hans', maintainer: user) }

        before do
          user.run_as { project.destroy }
        end

        it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('unknown_project') }
      end

      context 'when the package was sourceaccess protected' do
        let!(:package) { create(:forbidden_package, project: project, name: 'franz') }

        before do
          user.run_as { package.destroy }
        end

        it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('source_access_no_permission') }
      end
    end
  end
end
