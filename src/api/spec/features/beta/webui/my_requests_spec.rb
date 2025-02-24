require 'browser_helper'

RSpec.describe 'My Requests' do
  let(:user) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { create(:project_with_package, package_name: 'goal', maintainer: user) }
  let(:source_project) { create(:project_with_package, package_name: 'ball') }
  let(:other_target_project) { create(:project) }

  let!(:incoming_request) do
    create(:bs_request_with_submit_action, description: 'Incoming Request',
                                           source_package: source_project.packages.first,
                                           target_project: target_project)
  end

  let!(:outgoing_request) do
    create(:bs_request_with_submit_action, description: 'Outgoing Request',
                                           source_package: target_project.packages.first,
                                           target_project: other_target_project)
  end

  context 'user with requests' do
    before do
      Flipper.enable(:request_index)
      login user
      visit my_requests_path
    end

    it 'lists requests' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    it 'filter requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      choose('Incoming', allow_label_click: true)
      execute_script('$("#content-selector-filters-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end
  end
end
