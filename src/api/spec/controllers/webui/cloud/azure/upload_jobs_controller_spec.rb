require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Cloud::Azure::UploadJobsController, type: :controller, vcr: true do
  let(:azure_configuration) { build(:azure_configuration, application_id: 'Hey OBS!', application_key: 'Hey OBS?') }
  let(:user_with_azure_configuration) { create(:confirmed_user, login: 'tom', azure_configuration: azure_configuration) }
  let(:project) { create(:project, name: 'AzureImages') }
  let!(:package) { create(:package, name: 'MyAzureImage', project: project) }
  let(:upload_job) { create(:upload_job, user: user_with_azure_configuration) }
  let(:xml_response) do
    <<-HEREDOC
    <clouduploadjob name="6">
      <state>created</state>
      <details>waiting to receive image</details>
      <created>1513604055</created>
      <user>mlschroe</user>
      <target>azure</target>
      <project>Base:System</project>
      <repository>openSUSE_Factory</repository>
      <package>rpm</package>
      <arch>x86_64</arch>
      <filename>rpm-4.14.0-504.2.x86_64.rpm</filename>
      <size>1690860</size>
    </clouduploadjob>
    HEREDOC
  end
  let(:public_key) { file_fixture('cloudupload_public_key.txt').read }

  before do
    stub_request(:get, "#{CONFIG['source_url']}/cloudupload/_pubkey").and_return(body: public_key)
    login(user_with_azure_configuration)
  end

  describe 'GET #new' do
    context 'with valid parameters' do
      before do
        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          get :new, params: { project: 'AzureImages', package: 'MyAzureImage', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' }
        end
      end

      it { expect(response).to be_success }
      it {
        expect(assigns(:upload_job)).
          to have_attributes(project: 'AzureImages', package: 'MyAzureImage', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz')
      }
    end

    context 'with invalid parameters' do
      shared_context 'it redirects and assigns flash error' do
        before do
          Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
            get :new, params: params
          end
        end

        it { expect(flash[:error]).not_to be_nil }
        it { expect(response).to be_redirect }
      end

      context 'with a not existing package' do
        let(:params) { { project: 'AzureImages', package: 'not-existent', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' } }
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid filename' do
        let(:params) { { project: 'AzureImages', package: 'MyAzureImage', repository: 'standard', arch: 'x86_64', filename: 'appliance.rpm' } }
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid architecture' do
        let(:params) { { project: 'AzureImages', package: 'MyAzureImage', repository: 'standard', arch: 'i386', filename: 'appliance.raw.xz' } }
        include_context 'it redirects and assigns flash error'
      end
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        project:         'Cloud',
        package:         'azure',
        repository:      'standard',
        arch:            'x86_64',
        filename:        'appliance.raw.xz',
        target:          'azure',
        image_name:      'image001',
        subscription:    'myemailataws',
        container:       'container001',
        storage_account: 'mystorage',
        resource_group:  'mygroup'
      }
    end

    shared_context 'it redirects and assigns flash error' do
      before do
        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          post :create, params: { cloud_backend_upload_job: params }
        end
      end

      it { expect(flash[:error]).to match(/#{subject}/) }
      it { expect(response).to be_redirect }
    end

    context 'without backend configured' do
      subject { 'no cloud upload server configurated.' }

      include_context 'it redirects and assigns flash error'
    end

    context 'with an invalid filename' do
      subject { 'MyAzureImage.rpm' }

      before do
        params[:filename] = subject
      end

      include_context 'it redirects and assigns flash error'
    end

    context 'with a backend response' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?#{backend_params.to_param}" }
      let(:backend_params) do
        params.merge(target: 'azure', user: user_with_azure_configuration.login)
              .except(:image_name, :subscription, :container, :storage_account, :resource_group)
      end
      let(:additional_data) do
        {
          image_name:      'image001',
          subscription:    'myemailataws',
          container:       'container001',
          storage_account: 'mystorage',
          resource_group:  'mygroup'
        }
      end
      let(:post_body) do
        user_with_azure_configuration.azure_configuration.attributes.except('id', 'created_at', 'updated_at').merge(additional_data).to_json
      end

      before do
        stub_request(:post, path).with(body: post_body).and_return(body: xml_response)

        Feature.run_with_activated(:cloud_upload, :cloud_upload_azure) do
          post :create, params: { cloud_backend_upload_job: params }
        end
      end

      it { expect(flash[:success]).not_to be_nil }
      it { expect(Cloud::User::UploadJob.last.job_id).to eq(6) }
      it { expect(Cloud::User::UploadJob.last.user).to eq(user_with_azure_configuration) }
      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(response).to be_redirect }
    end
  end
end
