require 'webmock/rspec'

RSpec.describe SearchController, :vcr do
  render_views

  let(:user) { create(:confirmed_user, :with_home, login: 'foo') }
  let(:project) { user.home_project }

  before do
    login user
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
    before { get :project, params: { match: "@name='#{user.home_project.name}'" } }

    it_behaves_like 'find project'
  end

  describe 'search for project ids' do
    before { get :project_id, params: { match: "@name='#{user.home_project.name}'" } }

    it_behaves_like 'find project'
  end

  describe 'search for packages' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }

    before { get :package, params: { match: "@name='apacheX'" } }

    it_behaves_like 'find package'
  end

  describe 'search for packages with offset and limit' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }
    let!(:project) { create(:project_with_package, name: 'Foo', maintainer: user, package_name: 'apacheX') }

    context 'limit 1 and offset 1' do
      before { get :package, params: { limit: '1', offset: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end

    context 'limit 1' do
      let(:project) { user.home_project }

      before { get :package, params: { limit: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end

    context 'offset 1' do
      before { get :package, params: { offset: '1', match: "@name='apacheX'" } }

      it_behaves_like 'find package'
    end
  end

  describe 'search for package ids' do
    let!(:package) { create(:package, name: 'apacheX', project: user.home_project) }

    before { get :package_id, params: { match: "@name='apacheX'" } }

    it_behaves_like 'find package'

    context 'different xpath' do
      before { get :package_id, params: { match: "contains(@name,'apache')" } }

      it_behaves_like 'find package'
    end
  end

  describe 'search for attributes' do
    let(:name) { 'Maintained' }
    let(:namespace) { 'OBS' }

    context 'search project by attribute' do
      let(:project) { create(:project, name: 'Foo') }
      let!(:attrib) { create(:maintained_attrib, project: project) }

      before { get :project, params: { match: "attribute/@name='OBS:Maintained'" } }

      it_behaves_like 'find project'
    end
  end

  describe 'illegal predicates' do
    describe 'non closed parenthesis' do
      it 'shows an error', :aggregate_failures do
        get :bs_request, params: { match: '(' }, format: :xml

        expect(response).to have_http_status(:bad_request)
        expect(Nokogiri::XML(response.body).xpath('//status').attribute('code').value).to eq('illegal_xpath_error')
        expect(Nokogiri::XML(response.body).xpath('//status/summary').inner_text).to match(/Error found searching elements 'request' with xpath predicate: '\('./)
      end
    end

    describe 'closing parenthesis and closing square brackets' do
      it 'shows an error', :aggregate_failures do
        get :bs_request, params: { match: ')]' }, format: :xml

        expect(response).to have_http_status(:bad_request)
        expect(Nokogiri::XML(response.body).xpath('//status').attribute('code').value).to eq('illegal_xpath_error')
        expect(Nokogiri::XML(response.body).xpath('//status/summary').inner_text).to match(/Error found searching elements 'request' with xpath predicate: '\)\]'./)
      end
    end

    describe 'invalid predicate with null byte' do
      it 'shows an error', :aggregate_failures do
        get :bs_request, params: { match: "/e\u0000" }, format: :xml

        expect(response).to have_http_status(:bad_request)
        expect(Nokogiri::XML(response.body).xpath('//status').attribute('code').value).to eq('illegal_xpath_error')
        expect(Nokogiri::XML(response.body).xpath('//status/summary').inner_text).to match(%r{Error found searching elements 'request' with xpath predicate: '/e\\u0000'.})
      end
    end
  end

  describe 'search limited to 2 results', vcr: false do
    render_views false

    before do
      stub_const('CONFIG', CONFIG.merge('limit_for_search_results' => 2))
    end

    let!(:package1) { create(:package, name: 'package_1') }
    let!(:package2) { create(:package, name: 'package_2') }

    describe 'same number of results than the limit' do
      it 'returns results' do
        get :package, params: { match: "starts_with(@name,'package_')" }, format: :xml

        expect(response).to have_http_status(:success)
      end
    end

    describe 'more number of results than the limit' do
      let!(:package3) { create(:package, name: 'package_3') }

      describe 'search without ids' do
        it 'fails' do
          get :package, params: { match: "starts_with(@name,'package_')" }, format: :xml

          expect(response).to have_http_status(:forbidden)
        end
      end

      describe 'search with ids' do
        it 'returns results' do
          get :package_id, params: { match: "starts_with(@name,'package_')" }, format: :xml

          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end
