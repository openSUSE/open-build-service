require 'webmock/rspec'

RSpec.describe Webui::Cloud::Ec2::UploadJobsController, :vcr do
  let!(:ec2_configuration) { create(:ec2_configuration) }
  let!(:user_with_ec2_configuration) { create(:confirmed_user, login: 'tom', ec2_configuration: ec2_configuration) }
  let(:project) { create(:project, name: 'EC2Images') }
  let!(:package) { create(:package, name: 'MyEC2Image', project: project) }
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

  describe 'GET #new' do
    context 'with valid parameters' do
      before do
        get :new, params: { project: 'EC2Images', package: 'MyEC2Image', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' }
      end

      it { expect(response).to have_http_status(:success) }

      it {
        expect(assigns(:upload_job))
          .to have_attributes(project: 'EC2Images', package: 'MyEC2Image', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz')
      }
    end

    context 'with invalid parameters' do
      shared_context 'it redirects and assigns flash error' do
        before do
          get :new, params: params
        end

        it { expect(flash[:error]).not_to be_nil }
        it { expect(response).to be_redirect }
      end

      context 'with a not existing package' do
        let(:params) { { project: 'EC2Images', package: 'not-existent', repository: 'standard', arch: 'x86_64', filename: 'appliance.raw.xz' } }

        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid filename' do
        let(:params) { { project: 'EC2Images', package: 'MyEC2Image', repository: 'standard', arch: 'x86_64', filename: 'appliance.rpm' } }

        include_context 'it redirects and assigns flash error'
      end

      context 'with an invalid architecture' do
        let(:params) { { project: 'EC2Images', package: 'MyEC2Image', repository: 'standard', arch: 'i386', filename: 'appliance.raw.xz' } }

        include_context 'it redirects and assigns flash error'
      end
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        project: 'Cloud',
        package: 'aws',
        repository: 'standard',
        arch: 'x86_64',
        filename: 'appliance.raw.xz',
        region: 'us-east-1',
        ami_name: 'my-image',
        target: 'ec2'
      }
    end
    let(:error_response) do
      <<-HEREDOC
       <status code="400">
         <summary>no cloud upload server configured</summary>
       </status>
      HEREDOC
    end
    let(:post_url) { "#{CONFIG['source_url']}/cloudupload?arch=x86_64&filename=appliance.raw.xz&package=aws&project=Cloud&repository=standard&target=ec2&user=tom" }

    shared_context 'it redirects and assigns flash error' do
      before do
        post :create, params: { cloud_backend_upload_job: params }
      end

      it { expect(flash[:error]).to match(/#{subject}/) }
      it { expect(response).to be_redirect }
    end

    context 'without backend configured' do
      subject { 'no cloud upload server configured.' }

      before do
        stub_request(:post, post_url).and_return(body: error_response, status: 400)
      end

      include_context 'it redirects and assigns flash error'
    end

    context 'with an invalid filename' do
      subject { 'MyEC2Image.rpm' }

      before do
        params[:filename] = subject
      end

      include_context 'it redirects and assigns flash error'
    end

    context 'with a backend response' do
      let(:path) { "#{CONFIG['source_url']}/cloudupload?#{backend_params.to_param}" }
      let(:backend_params) do
        params.merge(target: 'ec2', user: user_with_ec2_configuration.login).except(:region, :ami_name)
      end
      let(:additional_data) do
        {
          region: 'us-east-1',
          ami_name: 'my-image'
        }
      end
      let(:post_body) do
        user_with_ec2_configuration.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(additional_data).to_json
      end

      before do
        stub_request(:post, path).with(body: post_body).and_return(body: xml_response)

        post :create, params: { cloud_backend_upload_job: params }
      end

      it { expect(flash[:success]).not_to be_nil }
      it { expect(Cloud::User::UploadJob.last.job_id).to eq(6) }
      it { expect(Cloud::User::UploadJob.last.user).to eq(user_with_ec2_configuration) }
      it { expect(response).to redirect_to(cloud_upload_index_path) }
      it { expect(response).to be_redirect }
    end
  end
end
