require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Cloud::UploadJobsController, type: :controller, vcr: true do
  let!(:ec2_configuration) { create(:ec2_configuration) }
  let!(:user_with_ec2_configuration) { create(:confirmed_user, login: 'tom', ec2_configuration: ec2_configuration) }
  let(:project) { create(:project, name: 'Apache') }
  let!(:package) { create(:package, name: 'apache2', project: project) }
  let(:upload_job) { create(:upload_job, user: user_with_ec2_configuration) }
  let(:xml_response) do
    <<-HEREDOC
    <clouduploadjob name="6">
      <state>created</state>
      <details>waiting to receive image</details>
      <created>1513604055</created>
      <user>mlschroe</user>
      <target>ec2</target>
      <project>Base:System</project>
      <repository>openSUSE_Factory</repository>
      <package>rpm</package>
      <arch>x86_64</arch>
      <filename>rpm-4.14.0-504.2.x86_64.rpm</filename>
      <size>1690860</size>
    </clouduploadjob>
    HEREDOC
  end

  before do
    login(user_with_ec2_configuration)
  end

  describe '#index' do
    context 'with cloud_upload feature enabled' do
      context 'without an EC2 configuration' do
        let(:user) { create(:user) }

        before do
          login(user)
        end

        before do
          Feature.run_with_activated(:cloud_upload) do
            get :index
          end
        end

        it { expect(response).to redirect_to(cloud_ec2_configuration_path) }
      end

      context 'with an EC2 configuration' do
        let(:path) { "#{CONFIG['source_url']}/cloudupload?name=#{upload_job.job_id}" }
        let(:xml_response_list) do
          <<-HEREDOC
          <clouduploadjoblist>
            #{xml_response}
          </clouduploadjoblist>
          HEREDOC
        end

        before do
          stub_request(:get, path).and_return(body: xml_response_list)
          Feature.run_with_activated(:cloud_upload) do
            get :index
          end
        end

        it { expect(assigns(:upload_jobs).length).to eq(1) }
        it { expect(assigns(:upload_jobs).first.id).to eq('6') }
        it { expect(response).to be_success }
      end
    end

    context 'with cloud_upload feature disabled' do
      before do
        Feature.run_with_deactivated(:cloud_upload) do
          get :index
        end
      end

      it { expect(response).to be_not_found }
    end
  end

  describe 'GET #new' do
    context 'with valid parameters' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          get :new, params: { project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' }
        end
      end

      it { expect(response).to be_success }
      it {
        expect(assigns(:upload_job)).
          to have_attributes(project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz')
      }
    end

    context 'with invalid parameters' do
      shared_context 'it redirects and assigns flash error' do
        before do
          Feature.run_with_activated(:cloud_upload) do
            get :new, params: params
          end
        end

        it { expect(flash[:error]).not_to be_nil }
        it { expect(response).to be_redirect }
      end

      context 'with a not existing package' do
        let(:params) { { project: 'Apache', package: 'not-existent', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' } }
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid filename' do
        let(:params) { { project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.rpm' } }
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid architecture' do
        let(:params) { { project: 'Apache', package: 'apache2', repository: 'standard', arch: 'i386', filename: 'appliance.raw.xz' } }
        include_context 'it redirects and assigns flash error'
      end
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        project:             'Cloud',
        package:             'aws',
        repository:          'standard',
        arch:                'x86_64',
        filename:            'appliance.raw.xz',
        region:              'us-east-1',
        virtualization_type: 'hvm',
        ami_name:            'my-image',
        target:              'ec2'
      }
    end

    shared_context 'it redirects and assigns flash error' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          post :create, params: { cloud_backend_upload_job: params }
        end
      end

      it { expect(flash[:error]).to match(/#{subject}/) }
      it { expect(response).to be_redirect }
    end

    context 'without backend configured' do
      let(:regex) { 'no cloud upload server configurated.' }
      subject { regex }
      include_context 'it redirects and assigns flash error'
    end

    context 'with invalid parameters' do
      context 'with an invalid filename' do
        subject { 'apache2.rpm' }
        before do
          params[:filename] = subject
        end
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid architecture' do
        subject { 'i386' }
        before do
          params[:arch] = subject
        end
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid virtualization type' do
        subject { 'kvm' }
        before do
          params[:virtualization_type] = subject
        end
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid ami_name' do
        subject { 'lorem ipsum' }
        before do
          params[:ami_name] = subject
        end
        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid region' do
        subject { 'nuernberg-southside' }
        before do
          params[:region] = subject
        end
        include_context 'it redirects and assigns flash error'
      end
    end

    context 'with a backend response' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?#{backend_params.to_param}" }
      let(:backend_params) do
        params.merge(target: 'ec2', user: user_with_ec2_configuration.login).except(:region, :virtualization_type, :ami_name)
      end
      let(:additional_data) do
        {
          region:              'us-east-1',
          virtualization_type: 'hvm',
          ami_name:            'my-image'
        }
      end
      let(:post_body) do
        user_with_ec2_configuration.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(additional_data).to_json
      end

      before do
        stub_request(:post, path).with(body: post_body).and_return(body: xml_response)

        Feature.run_with_activated(:cloud_upload) do
          post :create, params: { cloud_backend_upload_job: params }
        end
      end

      it { expect(flash[:success]).not_to be_nil }
      it { expect(Cloud::User::UploadJob.last.job_id).to eq(6) }
      it { expect(Cloud::User::UploadJob.last.user).to eq(user_with_ec2_configuration) }
      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(response).to be_redirect }
    end
  end

  describe 'DELETE #destroy' do
    let(:upload_job) { create(:upload_job, user: user_with_ec2_configuration) }
    let(:path) { "#{CONFIG['source_url']}/cloudupload/#{upload_job.job_id}?cmd=kill" }

    context 'of an existing upload job' do
      before do
        stub_request(:post, path).and_return(body: xml_response)
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: upload_job.job_id }
        end
      end

      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'of a not existing upload job' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: 42 }
        end
      end

      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an backend error response' do
      before do
        stub_request(:post, path).and_return(status: 404, body: 'not found')
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: upload_job.job_id }
        end
      end

      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end
end
