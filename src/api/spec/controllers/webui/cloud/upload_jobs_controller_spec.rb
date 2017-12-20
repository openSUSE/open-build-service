require 'rails_helper'

RSpec.describe Webui::Cloud::UploadJobsController, type: :controller, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let!(:ec2_configuration) { create(:ec2_configuration, user: user) }
  let!(:upload_job) { create(:upload_job, user: user) }
  let(:project) { create(:project, name: 'Apache') }
  let!(:package) { create(:package, name: 'apache2', project: project) }

  before do
    login(user)
  end

  describe 'src/api/spec/ #index' do
    context 'with cloud_upload feature enabled' do
      context 'without an EC2 configuration' do
        before do
          user.ec2_configuration = nil
          user.save

          Feature.run_with_activated(:cloud_upload) do
            get :index
          end
        end

        it { expect(response).to redirect_to(cloud_ec2_configuration_path) }
      end

      context 'with an EC2 configuration' do
        before do
          Feature.run_with_activated(:cloud_upload) do
            get :index
          end
        end

        it { expect(assigns(:upload_jobs)).to match_array([upload_job]) }
        it { expect(response).to have_http_status(:success) }
      end
    end

    context 'with cloud_upload feature disabled' do
      before do
        Feature.run_with_deactivated(:cloud_upload) do
          get :index
        end
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'GET #new' do
    before do
      Feature.run_with_activated(:cloud_upload) do
        get :new, params: { project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' }
      end
    end

    it { expect(response).to have_http_status(:success) }
    it {
      expect(assigns(:upload_job)).
        to have_attributes(project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz')
    }
  end

  describe 'POST #create' do
    context 'without backend response' do
      before do
        Feature.run_with_activated(:cloud_upload) do
          post :create, params: { cloud_backend_upload_job: {
            project: 'Apache', package: 'apache2', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz', region: 'us-east-1'
          } }
        end
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response).to have_http_status(302) }
    end

    context 'with a backend response' do
      let(:response) do
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
      let(:params) do
        ActionController::Parameters.new(
          project:    'Cloud',
          package:    'aws',
          repository: 'standard',
          arch:       'x86_64',
          filename:   'appliance.raw.gz',
          region:     'us-east-1'
        ).permit!
      end
      before do
        allow(Backend::Api::Cloud).to receive(:upload).with(user, params).and_return(response)

        Feature.run_with_activated(:cloud_upload) do
          post :create, params: { cloud_backend_upload_job: params }
        end
      end

      it { expect(flash[:success]).not_to be_nil }
      it { expect(Cloud::User::UploadJob.last.job_id).to eq(6) }
      it { expect(Cloud::User::UploadJob.last.user).to eq(user) }
      it { expect(response).to redirect_to(cloud_upload_index_path) }
    end
  end
end
