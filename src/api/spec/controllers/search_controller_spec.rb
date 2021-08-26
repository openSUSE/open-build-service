require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SearchController, vcr: true do
  render_views

  let(:user) { create(:confirmed_user, :with_home, login: 'foo') }
  let(:project) { user.home_project }

  before do
    login user
  end

  shared_examples 'find attribute' do
    it { expect(response).to have_http_status(:success) }
    it { expect(Xmlhash.parse(response.body)).to include('namespace' => namespace) }
    it { expect(Xmlhash.parse(response.body)).to include('name' => name) }
  end

  shared_examples 'find project' do
    it { expect(response).to have_http_status(:success) }
    it { expect(Xmlhash.parse(response.body)['project']['name']).to eq(project.name) }
  end

  shared_examples 'find package' do
    it { expect(response).to have_http_status(:success) }
    it { expect(Xmlhash.parse(response.body)['package']['project']).to eq(project.name) }
  end

  describe 'search for projects' do
    subject! { get :project, params: { match: "@name='#{user.home_project.name}'" } }

    it_behaves_like 'find project'
  end

  describe 'search for project ids' do
    subject! { get :project_id, params: { match: "@name='#{user.home_project.name}'" } }

    it_behaves_like 'find project'
  end

  describe 'search for packages' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }

    subject! { get :package, params: { match: "@name='apacheX'" } }

    it_behaves_like 'find package'
  end

  describe 'search for packages with offset and limit' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }
    let!(:project) { create(:project_with_package, name: 'Foo', maintainer: user, package_name: 'apacheX') }

    context 'limit 1 and offset 1' do
      subject! { get :package, params: { limit: '1', offset: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end

    context 'limit 1' do
      let(:project) { user.home_project }

      subject! { get :package, params: { limit: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end

    context 'offset 1' do
      subject! { get :package, params: { offset: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end
  end

  describe 'search for package ids' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }

    subject! { get :package_id, params: { match: "@name='apacheX'" } }

    it_behaves_like 'find package'

    context 'different xpath' do
      subject! { get :package_id, params: { match: "contains(@name,'apache')" } }

      it_behaves_like 'find package'
    end
  end

  describe 'search for attributes' do
    let(:name) { 'Maintained' }
    let(:namespace) { 'OBS' }

    context 'search project by attribute' do
      let(:project) { create(:project, name: 'Foo') }
      let!(:attrib) { create(:maintained_attrib, project: project) }

      subject! { get :project, params: { match: "[attribute/@name='OBS:Maintained']" } }

      it_behaves_like 'find project'
    end
  end
end
