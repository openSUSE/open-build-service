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

  before do
    Flipper.enable(:request_index)
    login user
  end

  context 'project with requests' do
    before do
      visit project_requests_beta_path(target_project)
    end

    it 'lists all requests by default' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    # rubocop:disable RSpec/ExampleLength
    it 'filters incoming requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      choose('Incoming', allow_label_click: true)
      execute_script('$("#requests-filter-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end

    it 'filters outgoing requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      choose('Outgoing', allow_label_click: true)
      execute_script('$("#requests-filter-form").submit()')

      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{other_incoming_request.number}")
    end
    # rubocop:enable RSpec/ExampleLength

    describe 'filters request by state' do
      let!(:new_request) do
        create(:bs_request_with_submit_action,
               description: 'This is in review state',
               target_project: target_project,
               state: :new)
      end

      # rubocop:disable RSpec/ExampleLength
      it 'shows requests with the selected state' do
        find_by_id('requests-dropdown-trigger').click if mobile?
        within('#filters') do
          click_on('filter-state-requests-button')
          check('new')
          sleep 1.5
        end
        execute_script('$("#requests-filter-form").submit()')

        within('#requests') do
          expect(page).to have_link(href: "/request/show/#{new_request.number}")
          expect(page).to have_css('.list-group-item span.badge.text-bg-secondary', text: 'new')
          expect(page).to have_no_link(href: "/request/show/#{incoming_request.number}")
        end
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end

  context 'project without requests' do
    before do
      visit project_requests_beta_path(another_source_project)
    end

    it 'shows no requests' do
      expect(page).to have_text('There are no requests available')
    end
  end
end
