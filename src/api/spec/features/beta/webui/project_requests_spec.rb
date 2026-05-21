require 'browser_helper'

RSpec.describe 'Project Requests' do
  let(:user) { create(:confirmed_user, login: 'henne') }
  let(:sender) { create(:confirmed_user, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, login: 'titan') }
  let(:source_project) { create(:project_with_package, package_name: 'ball', maintainer: sender) }
  let(:source_package) { source_project.packages.first }
  let(:target_project) { create(:project_with_package, package_name: 'goal', maintainer: receiver) }
  let(:target_package) { target_project.packages.first }

  let!(:incoming_request) do
    create(:bs_request_with_submit_action, creator: sender,
                                           description: 'Incoming Request',
                                           source_package: source_package,
                                           target_project: target_project,
                                           target_package: target_package)
  end

  let!(:outgoing_request) do
    create(:bs_request_with_submit_action, creator: receiver,
                                           description: 'Outgoing Request',
                                           source_project: target_project,
                                           source_package: target_package,
                                           target_project: source_project,
                                           target_package: source_package)
  end

  context 'project with requests' do
    before do
      Flipper.enable(:request_index)
      login user
      visit projects_requests_path(target_project)
    end

    it 'lists requests' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    it 'filter requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      uncheck('From Project', allow_label_click: true)
      uncheck('Review for Project', allow_label_click: true)
      execute_script('$("#content-selector-filters-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end
  end
end
