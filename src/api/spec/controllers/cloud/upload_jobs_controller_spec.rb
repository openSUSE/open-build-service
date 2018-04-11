# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Cloud::UploadJobsController, vcr: true do
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
  let(:xml_response_list) do
    <<-HEREDOC
    <clouduploadjoblist>
      #{xml_response}
    </clouduploadjoblist>
    HEREDOC
  end

  before do
    login(user_with_ec2_configuration)
  end

  describe '#show' do
    context 'with cloud_upload feature enabled' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?name=#{upload_job.job_id}" }
      let(:xml_response_list) do
        <<-HEREDOC
        <clouduploadjoblist>
          #{xml_response}
        </clouduploadjoblist>
        HEREDOC
      end

      context 'requesting upload jobs of another user' do
        let(:user) { create(:confirmed_user) }

        before do
          login(user)
          Feature.run_with_activated(:cloud_upload) do
            get :show, params: { id: upload_job.job_id }, format: 'xml'
          end
        end

        it { expect(response.header['X-Opensuse-Errorcode']).to eq('not_found') }
        it { expect(response).to have_http_status(:not_found) }
      end

      context 'with an EC2 configuration' do
        before do
          stub_request(:get, path).and_return(body: xml_response_list)
          get :show, params: { id: upload_job.job_id }, format: 'xml'
        end

        it 'returns an xml response with all cloud upload jobs listed' do
          expect(Xmlhash.parse(response.body)).to eq(Xmlhash.parse(xml_response_list))
        end
        it { expect(response).to be_success }
      end
    end

    context 'with cloud_upload feature disabled' do
      before do
        Feature.run_with_deactivated(:cloud_upload) do
          get :show, params: { id: upload_job.job_id }, format: 'xml'
        end
      end

      it { expect(response).to be_not_found }
    end
  end

  describe '#index' do
    context 'with cloud_upload feature enabled' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?name=#{upload_job.job_id}" }
      context 'without an EC2 configuration' do
        let(:user) { create(:confirmed_user) }

        before do
          login(user)
          Feature.run_with_activated(:cloud_upload) do
            get :index, format: 'xml'
          end
        end

        it { expect(response.header['X-Opensuse-Errorcode']).to eq('cloud_upload_job_no_config') }
        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'with an EC2 configuration' do
        before do
          stub_request(:get, path).and_return(body: xml_response_list)
          get :index, format: 'xml'
        end

        it 'returns an xml response with all cloud upload jobs listed' do
          expect(Xmlhash.parse(response.body)).to eq(Xmlhash.parse(xml_response_list))
        end
        it { expect(response).to be_success }
      end
    end

    context 'with cloud_upload feature disabled' do
      before do
        Feature.run_with_deactivated(:cloud_upload) do
          get :index, format: 'xml'
        end
      end

      it { expect(response).to be_not_found }
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        project:    'Cloud',
        package:    'aws',
        repository: 'standard',
        arch:       'x86_64',
        filename:   'appliance.raw.xz',
        region:     'us-east-1',
        ami_name:   'my-image',
        target:     'ec2'
      }
    end

    context 'requested with invalid data' do
      before do
        post :create, params: { region: 'nuernberg-southside' }, format: 'xml'
      end

      it { expect(response.header['X-Opensuse-Errorcode']).to eq('cloud_upload_job_invalid') }
      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'with a backend response' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?#{backend_params.to_param}" }
      let(:backend_params) do
        params.merge(target: 'ec2', user: user_with_ec2_configuration.login).except(:region, :ami_name)
      end
      let(:additional_data) do
        {
          region:   'us-east-1',
          ami_name: 'my-image'
        }
      end
      let(:post_body) do
        user_with_ec2_configuration.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(additional_data).to_json
      end

      before do
        stub_request(:post, path).with(body: post_body).and_return(body: xml_response)
        stub_request(:get, /#{CONFIG['source_url']}\/cloudupload\?name=\d+/).and_return(body: xml_response_list)
        post :create, params: params, format: 'xml'
      end

      it { expect(Cloud::User::UploadJob.last.job_id).to eq(6) }
      it { expect(Cloud::User::UploadJob.last.user).to eq(user_with_ec2_configuration) }
      it { expect(response).to be_success }
      it { expect(Xmlhash.parse(response.body)).to eq(Xmlhash.parse(xml_response_list)) }
    end
  end

  describe 'DELETE #destroy' do
    let(:upload_job) { create(:upload_job, user: user_with_ec2_configuration) }
    let(:path) { "#{CONFIG['source_url']}/cloudupload/#{upload_job.job_id}?cmd=kill" }

    context 'of an existing upload job' do
      before do
        stub_request(:post, path).and_return(body: xml_response)
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: upload_job.job_id }, format: 'xml'
        end
      end

      it { expect(response).to be_success }
    end

    context 'of a not existing upload job' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: 42 }, format: 'xml'
        end
      end

      it { expect(response.header['X-Opensuse-Errorcode']).to eq('not_found') }
      it { expect(response).to have_http_status(:not_found) }
    end

    context 'with a backend error response' do
      before do
        stub_request(:post, path).and_return(status: 404, body: 'not found')
        Feature.run_with_activated(:cloud_upload) do
          delete :destroy, params: { id: upload_job.job_id }, format: 'xml'
        end
      end

      it { expect(response.header['X-Opensuse-Errorcode']).to eq('cloud_upload_job_error') }
      it { expect(response).to have_http_status(:internal_server_error) }
    end
  end
end
