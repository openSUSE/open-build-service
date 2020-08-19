require 'webmock/rspec'
require 'rails_helper'

RSpec.describe Webui::Packages::FilesController, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }

  describe 'POST #create' do
    RSpec.shared_examples 'tests for create action' do
      before do
        login(user)
      end

      context 'without any uploaded file data' do
        it 'fails with an error message' do
          do_request(project_name: source_project, package_name: source_package)
          expect(response).to expected_failure_response
          expect(flash[:error]).to eq("Error while creating '' file: No file or URI given.")
        end
      end

      context 'with an invalid filename' do
        it 'fails with a backend error message' do
          do_request(project_name: source_project, package_name: source_package, filename: '.test')
          expect(response).to expected_failure_response
          expect(flash[:error]).to eq("Error while creating '.test' file: '.test' is not a valid filename.")
        end
      end

      context "adding a file that doesn't exist yet" do
        before do
          do_request(project_name: source_project,
                     package_name: source_package,
                     filename: 'newly_created_file',
                     file_type: 'local',
                     file: 'some_content')
        end

        it { expect(response).to have_http_status(expected_success_status) }
        it { expect(flash[:success]).to eq("The file 'newly_created_file' has been successfully saved.") }
        it { expect(source_package.source_file('newly_created_file')).to eq('some_content') }
      end

      context 'uploading a utf-8 file' do
        let(:file_to_upload) { File.read(File.expand_path(Rails.root.join('spec/support/files/chinese.txt'))) }

        before do
          do_request(project_name: source_project, package_name: source_package, filename: '学习总结', file: file_to_upload)
        end

        it { expect(response).to have_http_status(expected_success_status) }
        it { expect(flash[:success]).to eq("The file '学习总结' has been successfully saved.") }

        it 'creates the file' do
          expect { source_package.source_file('学习总结') }.not_to raise_error
          expect(CGI.escape(source_package.source_file('学习总结'))).to eq(CGI.escape(file_to_upload))
        end
      end

      context 'uploading a file from remote URL' do
        let(:service_content) do
          <<-XML.strip_heredoc.strip
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
        it { expect(flash[:success]).to eq("The file 'remote_file' has been successfully saved.") }

        # Uploading a remote file creates a service instead of downloading it directly!
        it 'creates a valid service file' do
          expect { source_package.source_file('_service') }.not_to raise_error
          expect { source_package.source_file('remote_file') }.to raise_error Backend::NotFoundError

          created_service = source_package.source_file('_service')
          expect(created_service).to eq(service_content)
        end
      end
    end

    context 'as ajax request' do
      let(:expected_success_status) { :ok }
      let(:expected_failure_response) { have_http_status(:bad_request) }

      def do_request(params)
        post :create, xhr: true, params: params
      end

      include_examples 'tests for create action'
    end

    context 'as non-ajax request' do
      let(:expected_success_status) { :found }
      let(:expected_failure_response) { redirect_to(root_path) }

      def do_request(params)
        post :create, params: params
      end

      include_examples 'tests for create action'
    end
  end
end
