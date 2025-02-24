require 'browser_helper'

RSpec.describe 'Package Requests' do
  let(:user) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { create(:project_with_package, package_name: 'goal') }
  let(:target_package) { target_project.packages.first }
  let(:source_project) { create(:project_with_package, package_name: 'ball') }
  let(:other_target_project) { create(:project_with_package, package_name: 'package_2') }

  let!(:incoming_request) do
    create(:bs_request_with_submit_action, description: 'Please take this',
                                           source_package: source_project.packages.first,
                                           target_project: target_project,
                                           target_package: target_package)
  end

  let!(:outgoing_request) do
    create(:bs_request_with_submit_action, description: 'How about this?',
                                           source_package: target_package,
                                           target_project: other_target_project)
  end

  before do
    Flipper.enable(:request_index)
    login user
  end

  context 'package with requests' do
    before do
      visit packages_requests_path(target_project, target_package)
    end

    it 'lists requests' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    it 'filters requests' do
      find_by_id('requests-dropdown-trigger').click if mobile? # open the filter dropdown
      choose('Incoming')
      execute_script('$("#content-selector-filters-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end
  end
end
