require 'browser_helper'

RSpec.describe 'Project Requests' do
  let(:user) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { create(:project_with_package, package_name: 'goal') }
  let(:source_project) { create(:project_with_package, package_name: 'ball') }
  let(:other_source_project) { create(:project_with_package, package_name: 'package_2') }
  let(:another_source_project) { create(:project_with_package, package_name: 'demo') }

  let!(:incoming_request) do
    create(:bs_request_with_submit_action, description: 'Please take this',
                                           source_package: source_project.packages.first,
                                           target_project: target_project)
  end

  let!(:other_incoming_request) do
    create(:bs_request_with_submit_action, description: 'This is very important',
                                           source_package: other_source_project.packages.first,
                                           target_project: target_project)
  end

  let!(:outgoing_request) do
    create(:bs_request_with_submit_action, description: 'How about this?',
                                           source_package: target_project.packages.first,
                                           target_project: other_source_project)
  end

  context 'project with requests' do
    before do
      Flipper.enable(:request_index)
      login user
      visit projects_requests_path(target_project)
    end

    it 'lists requests' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    # rubocop:disable RSpec/ExampleLength
    it 'filter requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      check('Incoming', allow_label_click: true)
      execute_script('$("#content-selector-filters-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end
    # rubocop:enable RSpec/ExampleLength
  end

  context 'project without requests' do
    before do
      Flipper.enable(:request_index)
      login user
      visit projects_requests_path(another_source_project)
    end

    it 'shows no requests' do
      expect(page).to have_text('There are no requests available')
    end
  end
end
