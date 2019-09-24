require 'browser_helper'

RSpec.feature 'FactoryDashboard', type: :feature, js: true, vcr: true do
  let(:maintainer) { create(:confirmed_user, login: 'factory_admin', email: 'factory_admin@example.org') }
  let(:factory) { create(:project, name: 'openSUSE:Factory') }
  let!(:factory_staging) { create(:project, name: 'openSUSE:Factory:Staging') }

  let(:factory_distribution) { ::ObsFactory::Distribution.find(factory.name) }
  let!(:staging_projects) { ::ObsFactory::StagingProject.for(factory_distribution) }

  let!(:dashboard) { create(:package, name: 'dashboard', project: factory_staging) }
  let(:source_package) { create(:package, :as_submission_source) }
  let(:target_package) { create(:package, name: 'target_package', project: factory) }
  let(:staging_project_a) { create(:project, name: "#{factory_staging.name}:A", description: description) }
  let!(:factory_ring_bootstrap) { create(:project, name: 'openSUSE:Factory:Rings:0-Bootstrap', description: 'Factory ring project') }
  let!(:minimal_x) { create(:project, name: 'openSUSE:Factory:Rings:1-MinimalX') }

  let(:group) { create(:group, title: 'factory-staging') }

  let(:declined_bs_request) do
    create(:declined_bs_request,
           target_package: target_package,
           source_package: source_package)
  end

  let(:staged_request) do
    create(:bs_request_with_submit_action,
           number: 31_337,
           review_by_project: staging_project_a.name,
           review_by_group: group.title,
           target_package: target_package,
           source_package: source_package)
  end

  let(:description) do
    <<-DESCRIPTION
        requests:
          - { author: #{maintainer.login}, id: 31337, package: #{source_package.name}, type: submit }
    DESCRIPTION
  end

  before do
    login maintainer
    staging_project_a
    staged_request
    declined_bs_request
  end

  shared_examples 'bento layout' do
    scenario 'images and title' do
      expect(page).to have_xpath('//div[@id=\'breadcrump\']')
      expect(page).to have_title("#{factory.name} Staging Dashboard")
      expect(page).to have_xpath('//img[@title=\'Logo\']')
      expect(page).to have_xpath('//a[@id=\'header-logo\']')
    end
  end

  shared_examples 'check assets' do
    scenario 'imgs' do
      page.all('img').each do |img|
        visit img[:src]
        expect(page).not_to have_text('No route matches')
      end
    end
  end

  describe 'the dashboard' do
    before do
      visit dashboard_path(factory.name)
    end

    scenario 'title links to staging projects' do
      within('h2:first-child') do
        expect(page).to have_link('Staging Projects', href: staging_projects_path(factory.name))
      end
      expect(page).to have_link("Repositories of #{factory.name}", href: project_show_path(factory.name))
    end

    context 'bento' do
      it_behaves_like 'bento layout'
      it_behaves_like 'check assets'
    end
  end

  describe 'the staging_projects' do
    before do
      visit staging_projects_path(factory.name)
    end

    scenario 'it has a link to staging project' do
      within('.letter') do
        expect(page).to have_link('A')
      end

      within('.staging_backlog') do
        expect(page).to have_link(target_package.name)
      end
    end

    context 'bento' do
      it_behaves_like 'bento layout'
      it_behaves_like 'check assets'
    end
  end

  describe 'a specific staging_project' do
    before do
      visit staging_project_path(project: factory.name, project_name: 'A')
    end

    scenario 'target package is there' do
      within('li.review.submit.request') do
        expect(page).to have_link(target_package.name)
      end
    end

    scenario 'status messages and icons classes' do
      within('div.factory-summary') do
        expect(page).to have_css('img[class=\'icons-accept\']')
        expect(page).to have_css('img[class=\'icons-error\']')
      end
    end

    context 'bento' do
      it_behaves_like 'bento layout'
      it_behaves_like 'check assets'
    end
  end
end
