require 'browser_helper'
require 'bootstrap/support/page/monitor_page'

RSpec.feature 'Monitor', type: :feature, js: true do
  describe 'monitor' do
    let(:admin_user) { create(:admin_user) }
    let!(:project) { create(:project, name: 'TestProject') }
    let!(:package1) { create(:package, project: project, name: 'TestPackage') }
    let!(:package2) { create(:package, project: project, name: 'SecondPackage') }
    let!(:repository1) { create(:repository, project: project, name: 'openSUSE_Tumbleweed', architectures: ['x86_64', 'i586']) }
    let!(:repository2) { create(:repository, project: project, name: 'openSUSE_Leap_42.3', architectures: ['x86_64', 'i586']) }
    let!(:repository3) { create(:repository, project: project, name: 'openSUSE_Leap_42.2', architectures: ['x86_64', 'i586']) }

    let(:build_results_xml) do
      <<-XML
      <resultlist state="dc66a487ea4d97b4f157d075a0e747b9">
        <result project="TestProject" repository="openSUSE_Tumbleweed" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="succeeded">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.3" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.2" arch="x86_64" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Tumbleweed" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.3" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
        <result project="TestProject" repository="openSUSE_Leap_42.2" arch="i586" code="published" state="published">
          <status package="SecondPackage" code="broken">
            <details>no source uploaded</details>
          </status>
          <status package="TestPackage" code="broken">
            <details>no source uploaded</details>
          </status>
        </result>
      </resultlist>
      XML
    end

    before do
      login admin_user
      allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(build_results_xml)
      visit project_monitor_path(project.name)
    end

    scenario 'filtering build results by architecture' do
      page = Page::MonitorPage.new(:architectures)
      page.filter('i586')

      expect(page).to have_column('i586')
      expect(page).not_to have_column('x86_64')
    end

    scenario 'filtering build results by repository' do
      page = Page::MonitorPage.new(:repositories)
      page.filter('openSUSE_Leap_42.2')
      page.filter('openSUSE_Leap_42.3')

      expect(page).to have_column('openSUSE_Leap_42.2')
      expect(page).to have_column('openSUSE_Leap_42.3')
      expect(page).not_to have_column('Tumbleweed')
    end

    scenario 'filtering build results by status' do
      page = Page::MonitorPage.new(:status)
      page.filter('succeeded')

      expect(page).to have_row('TestPackage')
      expect(page).not_to have_row('SecondPackage')
    end
  end
end
