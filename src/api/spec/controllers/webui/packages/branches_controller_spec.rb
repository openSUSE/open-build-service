require 'webmock/rspec'

RSpec.describe Webui::Packages::BranchesController, :vcr do
  let(:admin) { create(:admin_user, login: 'admin') }
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:existing_project) { create(:project_with_package, name: 'existing_project', package_name: 'existing_package', maintainer: user) }

  describe 'POST #create' do
    before do
      login(user)
    end

    it 'shows an error if source package does not exist' do
      post :create, params: { linked_project: source_project, linked_package: 'does_not_exist' }
      expect(flash[:error]).to eq('Failed to branch: Package not found: home:tom/does_not_exist')
      expect(response).to redirect_to(root_path)
    end

    it 'shows an error if source package parameter not provided' do
      post :create, params: { linked_project: source_project }
      expect(flash[:error]).to eq('Failed to branch: Linked Package parameter missing')
      expect(response).to redirect_to(root_path)
    end

    it 'shows an error if source project does not exist' do
      post :create, params: { linked_project: 'does_not_exist', linked_package: source_package }
      expect(flash[:error]).to eq('Failed to branch: Project not found: does_not_exist')
      expect(response).to redirect_to(root_path)
    end

    it 'shows an error if user has no permissions for source project' do
      post :create, params: { linked_project: source_project, linked_package: source_package, target_project: 'home:admin:nope' }
      expect(flash[:error]).to eq('Sorry, you are not authorized to create this project.')
      expect(response).to redirect_to(root_path)
    end

    it 'shows an error if source project parameter not provided' do
      post :create, params: { linked_package: source_package }
      expect(flash[:error]).to eq('Failed to branch: Linked Project parameter missing')
      expect(response).to redirect_to(root_path)
    end

    it "shows an error if current revision parameter is provided, but there wasn't any revision before" do
      post :create, params: { linked_project: source_project, linked_package: source_package, current_revision: true, revision: 2 }
      expect(flash[:error]).to eq('Package has no source revision yet')
      expect(response).to redirect_to(root_path)
    end

    it 'shows an error if the target package exists already' do
      post :create, params: { linked_project: source_project, linked_package: source_package, target_project: existing_project.name, target_package: 'existing_package' }
      expect(flash[:notice]).to eq('You have already branched this package')
    end

    context 'with default parameters' do
      before do
        post :create, params: { linked_project: source_project, linked_package: source_package }
      end

      it { expect(flash[:success]).to eq('Successfully branched package') }

      it 'redirects to the branched package' do
        expect(response).to redirect_to(package_show_path(project: "#{source_project.name}:branches:#{source_project.name}",
                                                          package: source_package.name.to_s))
      end
    end

    context 'with target package name' do
      before do
        post :create, params: { linked_project: source_project, linked_package: source_package, target_package: 'new_package_name' }
      end

      it { expect(flash[:success]).to eq('Successfully branched package') }

      it 'redirects to the branched package' do
        expect(response).to redirect_to(package_show_path(project: "#{source_project.name}:branches:#{source_project.name}",
                                                          package: 'new_package_name'))
      end
    end

    context 'with currrent revision parameter' do
      let(:source_package) { create(:package_with_revisions, name: 'package_with_revisions', project: source_project, revision_count: 4) }
      let(:url) { "#{CONFIG['source_url']}/source/#{source_package.project}/#{source_package}?expand=1&rev=2" }
      let(:current_revision) do
        '<directory name="package_with_revision" rev="2" vrev="2" srcmd5="efbe5f0a5dd48df5129b4319df43aa45">
            <entry name="somefile.txt" md5="c4ca4238a0b923820dcc509a6f75849b" size="2" mtime="1536673689" />
          </directory>'
      end
      let(:set_revision) { 'efbe5f0a5dd48df5129b4319df43aa45' }

      let(:branched_package) { Package.find_by_project_and_name("#{source_project.name}:branches:#{source_project.name}", source_package.name) }

      before do
        stub_request(:get, url).and_return(body: current_revision)
        post :create, params: { linked_project: source_project, linked_package: source_package, current_revision: true, revision: 2 }
      end

      it { expect(flash[:success]).to eq('Successfully branched package') }

      it 'redirects to the branched package' do
        expect(response).to redirect_to(package_show_path(project: "#{source_project.name}:branches:#{source_project.name}",
                                                          package: source_package.name))
      end

      it { expect(branched_package.linkinfo['rev']).to eq(set_revision) }
    end
  end
end
