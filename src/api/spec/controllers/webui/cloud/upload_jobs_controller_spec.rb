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

        it { expect(response).to redirect_to(cloud_configuration_index_path) }
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
