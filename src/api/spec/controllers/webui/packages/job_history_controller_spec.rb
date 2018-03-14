require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Packages::JobHistoryController, type: :controller, vcr: true do
  describe 'GET #index' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:source_project) { user.home_project }
    let(:package) { create(:package, name: 'package', project: source_project) }
    let(:repo_for_source_project) do
      repo = create(:repository, project: source_project, architectures: ['i586'])
      source_project.store
      repo
    end

    context 'without a valid respository' do
      before do
        get :index, params: { package_name: package, project: source_project, repository: 'fake_repo', arch: 'i586' }
      end

      it { expect(flash[:error]).to_not be_empty }
      it { expect(response).to redirect_to(package_binaries_path(package: package, project: source_project, repository: 'fake_repo')) }
    end

    context 'without a valid architecture' do
      before do
        login(user)
        get :index, params: { package_name: package, project: source_project, repository: repo_for_source_project.name, arch: 'i58' }
      end

      it { expect(flash[:error]).to_not be_empty }
      it 'should redirect to package_binaries_path' do
        expect(response).to redirect_to(package_binaries_path(package: package,
                                                              project: source_project, repository: repo_for_source_project.name))
      end
    end

    context 'with job history' do
      let(:local_job_history) do
        { revision:      '1',
          srcmd5:        '2ac8bd685591b40e412ee99b182f94c2',
          build_counter: '1',
          worker_id:     'vagrant-openSUSE-Leap:1',
          host_arch:     'x86_64',
          reason:        'new build',
          ready_time:    1_492_687_344,
          start_time:    1_492_687_470,
          end_time:      1_492_687_507,
          total_time:    37,
          code:          'succeed' }
      end

      before do
        login(user)
        repo_for_source_project
        path = "#{CONFIG['source_url']}/build/#{user.home_project}/#{repo_for_source_project.name}/i586/_jobhistory?limit=100&package=#{package}"
        stub_request(:get, path).and_return(body:
        %(<jobhistlist>
          <jobhist package='#{package.name}' rev='1' srcmd5='2ac8bd685591b40e412ee99b182f94c2' versrel='7-3' bcnt='1' readytime='1492687344'
          starttime='1492687470' endtime='1492687507' code='succeed' uri='http://127.0.0.1:41355' workerid='vagrant-openSUSE-Leap:1'
          hostarch='x86_64' reason='new build' verifymd5='2ac8bd685591b40e412ee99b182f94c2'/>
        </jobhistlist>))
        get :index, params: { package_name: package, project: source_project, repository: repo_for_source_project.name, arch: 'i586' }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template(:index) }
      it { expect(assigns(:jobshistory).count).to eq(1) }
      it { expect(assigns(:jobshistory).first).to have_attributes(local_job_history) }
    end
  end
end
