require 'webmock/rspec'

RSpec.describe Webui::Packages::FilesController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }

  describe 'POST #create' do
    let(:expected_success_status) { :found }
    let(:expected_failure_response) { redirect_to(root_path) }

    def do_request(params)
      post :create, params: params
    end

    before do
      login(user)
    end

    context 'without any uploaded file data' do
      it 'fails with an error message' do
        do_request(project_name: source_project, package_name: source_package)
        expect(response).to expected_failure_response
        expect(flash[:error]).to eq('Error while creating  files: No file or URI given.')
      end
    end

    context 'with an invalid filename' do
      it 'fails with a backend error message' do
        do_request(project_name: source_project, package_name: source_package, filename: '.test')
        expect(response).to expected_failure_response
        expect(flash[:error]).to eq("Error while creating .test files: '.test' is not a valid filename.")
      end
    end

    context "adding a file that doesn't exist yet" do
      before do
        do_request(project_name: source_project,
                   package_name: source_package,
                   files: [fixture_file_upload('newly_created_file')])
      end

      it { expect(response).to have_http_status(expected_success_status) }
      it { expect(flash[:success]).to eq('newly_created_file have been successfully saved.') }
      it { expect(source_package.source_file('newly_created_file')).to eq("some_content\n") }
    end

    context 'uploading a utf-8 file' do
      let(:file_to_upload) { fixture_file_upload('学习总结') }

      before do
        do_request(project_name: source_project, package_name: source_package, files: [file_to_upload])
      end

      it { expect(response).to have_http_status(expected_success_status) }
      it { expect(flash[:success]).to eq('学习总结 have been successfully saved.') }

      it 'creates the file' do
        expect { source_package.source_file('学习总结') }.not_to raise_error
        expect(CGI.escape(source_package.source_file('学习总结'))).to eq(CGI.escape(file_to_upload.tempfile.read))
      end
    end

    context 'uploading a file from remote URL' do
      let(:service_content) do
        <<~XML.strip
          <services>
            <service name="download_url">
              <param name="host">raw.github.com</param>
              <param name="protocol">https</param>
              <param name="path">/openSUSE/open-build-service/master/.gitignore</param>
              <param name="filename">remote_file</param>
            </service>
          </services>
        XML
      end

      before do
        do_request(project_name: source_project, package_name: source_package, filename: 'remote_file',
                   file_url: 'https://raw.github.com/openSUSE/open-build-service/master/.gitignore')
      end

      after do
        # Make sure the service only once get's created
        source_package.destroy
      end

      it { expect(response).to have_http_status(expected_success_status) }
      it { expect(flash[:success]).to eq('remote_file have been successfully saved.') }

      # Uploading a remote file creates a service instead of downloading it directly!
      it 'creates a valid service file' do
        expect { source_package.source_file('_service') }.not_to raise_error
        expect { source_package.source_file('remote_file') }.to raise_error Backend::NotFoundError

        created_service = source_package.source_file('_service')
        expect(created_service).to eq(service_content)
      end
    end
  end

  describe 'POST #update' do
    before do
      login(user)
    end

    context 'as ajax request' do
      def do_request(params)
        put :update, xhr: true, params: params
      end

      let(:existing_file) do
        post :create, params: { project_name: source_project,
                                package_name: source_package,
                                files: [fixture_file_upload('newly_created_file')] }
      end

      context 'modifies an existing file' do
        before do
          do_request(project_name: source_project,
                     package_name: source_package,
                     filename: 'newly_created_file')
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(flash[:success]).to eq("'newly_created_file' has been successfully saved.") }
        it { expect(source_package.source_file('newly_created_file')).to eq('') }
      end
    end

    context 'as non-ajax request' do
      def do_request(params)
        put :update, params: params
      end

      let(:existing_file) do
        post :create, params: { project_name: source_project,
                                package_name: source_package,
                                files: [fixture_file_upload('newly_created_file')] }
      end

      context 'modifies an existing file' do
        it {
          expect do
            do_request(project_name: source_project,
                       package_name: source_package,
                       filename: 'newly_created_file')
          end.to raise_error(Pundit::AuthorizationNotPerformedError)
        }
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      login(user)
      allow_any_instance_of(Package).to receive(:delete_file).and_return(true)
    end

    def do_request
      delete :destroy, params: { project_name: user.home_project, package_name: source_package, filename: 'the_file' }
    end

    context 'with successful backend call' do
      before do
        do_request
      end

      it { expect(flash[:success]).to eq("File 'the_file' removed successfully") }
      it { expect(assigns(:package)).to eq(source_package) }
      it { expect(assigns(:project)).to eq(user.home_project) }
      it { expect(response).to redirect_to(package_show_path(project: user.home_project, package: source_package)) }
    end

    context 'with not successful backend call' do
      before do
        allow_any_instance_of(Package).to receive(:delete_file).and_raise(Backend::NotFoundError)
        do_request
      end

      it { expect(flash[:error]).to eq("Failed to remove file 'the_file'") }
    end

    it 'calls delete_file method' do
      allow_any_instance_of(Package).to receive(:delete_file).with('the_file')
      do_request

      expect(flash[:success]).to eq("File 'the_file' removed successfully")
    end

    context 'with no permissions' do
      let(:other_user) { create(:confirmed_user) }

      before do
        login other_user
        do_request
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to update this package.') }
      it { expect(Package.where(name: 'my_package')).to exist }
    end
  end

  describe 'GET #show' do
    context 'the file comes from an scmsync project' do
      let(:scmsync_project) { create(:project, name: 'lorem', scmsync: 'https://github.com/example/scmsync-project.git', maintainer: user) }
      let(:scmsync_package) { create(:package_with_file, name: 'scmsync_package', project: scmsync_project, file_name: 'README.txt', file_content: 'foo bar') }

      before do
        login(user)
        get :show, params: { project_name: scmsync_project.name, package_name: scmsync_package.name, filename: 'README.txt' }
      end

      it { expect(flash[:error]).to eq('The project lorem is configured through scmsync. This is not supported by the OBS frontend') }
      it { expect(response).to redirect_to(project_show_path(scmsync_project)) }
    end
  end

  describe 'GET #blame' do
    before do
      allow_any_instance_of(Package).to receive(:file_exists?).with('aaa_base.spec', {}).and_return(true)
      allow(Backend::Api::Sources::Package).to receive(:blame).with(source_project.name, source_package.name, 'aaa_base.spec', {}).and_return(file_fixture('aaa_base.spec.blame').read)
      get :blame, params: { project_name: source_project, package_name: source_package, file_filename: 'aaa_base.spec' }
    end

    it 'sets @blame_info instance' do
      blame_info = assigns(:blame_info)

      # Corresponds to the number of groups of lines with the same commit in a row in the blame fixture
      expect(blame_info.size).to eq(112)
    end

    it 'groups lines correctly' do
      blame_group = assigns(:blame_info)[5]

      # This corresponds to the data in group between lines 8 and 16 in the blame fixture
      expect(blame_group.size).to eq(9)
      expect(blame_group.map { |g| g['revision'] }.uniq).to eq(['104'])
    end

    it 'parses lines correctly' do
      blame_line = assigns(:blame_info)[5][0]

      # This corresponds to the data in line number 8 in the blame fixture
      expect(blame_line['file']).to eq('1:')
      expect(blame_line['login']).to eq('unknown')
      expect(blame_line['line']).to eq('6')
      expect(blame_line['content']).to eq('# All modifications and additions to the file contributed by third parties')
    end
  end
end
