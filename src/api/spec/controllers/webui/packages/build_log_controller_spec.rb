require 'webmock/rspec'
RSpec.describe Webui::Packages::BuildLogController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:source_project_with_plus) { create(:project, name: 'foo++bar') }
  let(:package_of_project_with_plus) { create(:package, name: 'some_package', project: source_project_with_plus) }
  let(:source_package_with_plus) { create(:package, name: 'my_package++special', project: source_project) }
  let(:repo_leap_42_2) { create(:repository, name: 'leap_42.2', project: source_project, architectures: ['i586']) }
  let(:architecture) { repo_leap_42_2.architectures.first }

  RSpec.shared_examples 'build log' do
    before do
      repo_leap_42_2
      source_project.store(login: user)
    end

    context 'successfully' do
      before do
        path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?arch=i586" \
               "&package=#{source_package}&repository=#{repo_leap_42_2}&view=status"
        stub_request(:get, path).and_return(body:
          %(<resultlist state='123'>
             <result project='#{user.home_project}' repository='#{repo_leap_42_2}' arch='i586'>
               <binarylist/>
             </result>
            </resultlist>))
        do_request project: source_project, package: source_package, repository: repo_leap_42_2.name, arch: 'i586', format: 'js'
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "successfully with a package which name that includes '+'" do
      before do
        path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?arch=i586" \
               "&package=#{source_package_with_plus}&repository=#{repo_leap_42_2}&view=status"
        stub_request(:get, path).and_return(body:
          %(<resultlist state='123'>
             <result project='#{user.home_project}' repository='#{repo_leap_42_2}' arch='i586'>
               <binarylist/>
             </result>
            </resultlist>))
        do_request project: source_project, package: source_package_with_plus, repository: repo_leap_42_2.name, arch: 'i586', format: 'js'
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context "successfully with a project which name that includes '+'" do
      let(:repo_leap_45_1) { create(:repository, name: 'leap_45.1', project: source_project_with_plus, architectures: ['i586']) }

      before do
        repo_leap_45_1
        source_project_with_plus.store

        path = "#{CONFIG['source_url']}/build/#{source_project_with_plus}/_result?arch=i586" \
               "&package=#{package_of_project_with_plus}&repository=#{repo_leap_45_1}&view=status"
        stub_request(:get, path).and_return(body:
          %(<resultlist state='123'>
             <result project='#{source_project_with_plus}' repository='#{repo_leap_45_1}' arch='i586'>
               <binarylist/>
             </result>
            </resultlist>))
        do_request project: source_project_with_plus, package: package_of_project_with_plus,
                   repository: repo_leap_45_1.name, arch: 'i586', format: 'js'
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'with a protected package' do
      let!(:flag) { create(:sourceaccess_flag, project: source_project) }

      before do
        do_request project: source_project, package: source_package, repository: repo_leap_42_2.name, arch: 'i586', format: 'js'
      end

      it { expect(flash[:error]).to eq('Could not access build log') }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
    end

    context 'with a non existent package' do
      before do
        do_request project: source_project, package: 'nonexistent', repository: repo_leap_42_2.name, arch: 'i586'
      end

      it { expect(flash[:error]).to eq("Couldn't find package 'nonexistent' in project '#{source_project}'. Are you sure it exists?") }
      it { expect(response).to redirect_to(project_show_path(project: source_project)) }
    end

    context 'with a non existent project' do
      before do
        do_request project: 'home:foo', package: 'nonexistent', repository: repo_leap_42_2.name, arch: 'i586'
      end

      it { expect(flash[:error]).to eq("Couldn't find project 'home:foo'. Are you sure it still exists?") }
      it { expect(response).to redirect_to(root_path) }
    end
  end

  describe 'GET #package_live_build_log' do
    def do_request(params)
      get :live_build_log, params: params
    end

    it_behaves_like 'build log'

    context 'with a nonexistent repository' do
      before do
        do_request project: source_project, package: source_package, repository: 'nonrepository', arch: 'i586'
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response).to redirect_to(package_show_path(source_project, source_package)) }
    end

    context 'with a nonexistent architecture' do
      before do
        do_request project: source_project, package: source_package, repository: repo_leap_42_2.name, arch: 'i566'
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response).to redirect_to(package_show_path(source_project, source_package)) }
    end

    context 'with a multibuild package' do
      let(:params) do
        { project: source_project,
          package: "#{source_package}:multibuild-package",
          repository: repo_leap_42_2.name,
          arch: architecture.name }
      end
      let(:starttime) { 1.hour.ago.to_i }

      before do
        path = "#{CONFIG['source_url']}/build/#{source_project}/_result?arch=i586" \
               "&package=#{source_package}:multibuild-package&repository=#{repo_leap_42_2}&view=status"
        stub_request(:get, path).and_return(body: %(<resultlist state='123'>
             <result project='#{source_project}' repository='#{repo_leap_42_2}' arch='i586' code="unpublished" state="unpublished">
              <status package="#{source_package}:multibuild-package" code="succeeded" />
             </result>
            </resultlist>))

        path = "#{CONFIG['source_url']}/build/#{source_project}/#{repo_leap_42_2}/i586/_builddepinfo" \
               "?package=#{source_package}:multibuild-package&view=revpkgnames"
        stub_request(:get, path).and_return(body: %(<builddepinfo>
              <package name="#{source_package}:multibuild-package">
              <source>apache2</source>
              <pkgdep>apache2</pkgdep>
              </package>
            </builddepinfo>))

        path = "#{CONFIG['source_url']}/build/#{source_project}/#{repo_leap_42_2}/i586/#{source_package}:multibuild-package/_jobstatus"
        body = "<jobstatus workerid='42' starttime='#{starttime}'/>"
        stub_request(:get, path).and_return(body: body)

        do_request params
      end

      it { expect(assigns(:what_depends_on)).to eq(['apache2']) }
      it { expect(assigns(:status)).to eq('succeeded') }
      it { expect(assigns(:workerid)).to eq('42') }
      it { expect(assigns(:buildtime)).to be_within(1).of(1.hour.to_i) }
      it { expect(assigns(:package)).to eq(source_package) }
      it { expect(assigns(:package_name)).to eq("#{source_package}:multibuild-package") }
    end
  end

  describe 'GET #update_build_log' do
    def do_request(params)
      get :update_build_log, params: params, xhr: true
    end

    it_behaves_like 'build log'

    context 'with a nonexistent repository' do
      before do
        do_request project: source_project, package: source_package, repository: 'nonrepository', arch: 'i586'
      end

      it { expect(assigns(:errors)).not_to be_nil }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'with a nonexistent architecture' do
      before do
        do_request project: source_project, package: source_package, repository: repo_leap_42_2.name, arch: 'i566'
      end

      it { expect(assigns(:errors)).not_to be_nil }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'for multibuild package' do
      let(:params) do
        { project: source_project,
          package: "#{source_package}:multibuild-package",
          repository: repo_leap_42_2.name,
          arch: architecture.name }
      end

      before do
        path = "#{CONFIG['source_url']}/build/#{source_project}/#{repo_leap_42_2}/i586/#{source_package}:multibuild-package/_log?view=entry"
        body = "<directory><entry name=\"_log\" size=\"#{32 * 1024}\" mtime=\"1492267770\" /></directory>"
        stub_request(:get, path).and_return(body: body)
        do_request params
      end

      it { expect(assigns(:log_chunk)).not_to be_nil }
      it { expect(assigns(:package)).to eq(source_package) }
      it { expect(assigns(:package_name)).to eq("#{source_package}:multibuild-package") }
      it { expect(assigns(:project)).to eq(source_project) }
      it { expect(assigns(:offset)).to eq(0) }
    end
  end
end
