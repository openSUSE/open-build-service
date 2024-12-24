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

    it 'lists all requests by default' do
      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{outgoing_request.number}")
    end

    # rubocop:disable RSpec/ExampleLength
    it 'filters incoming requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      choose('Incoming', allow_label_click: true)
      execute_script('$("#filter-form").submit()')

      expect(page).to have_link(href: "/request/show/#{incoming_request.number}")
      expect(page).to have_link(href: "/request/show/#{other_incoming_request.number}")
      expect(page).to have_no_link(href: "/request/show/#{outgoing_request.number}")
    end

    it 'filters outgoing requests' do
      find_by_id('requests-dropdown-trigger').click if mobile?
      choose('Outgoing', allow_label_click: true)
      execute_script('$("#filter-form").submit()')

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
          check('new')
          sleep 2
        end
        execute_script('$("#filter-form").submit()')

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
      Flipper.enable(:request_index)
      login user
      visit projects_requests_path(another_source_project)
    end

    it 'shows no requests' do
      expect(page).to have_text('There are no requests available')
    end
  end

  describe 'filter by staging projects', :vcr do
    let(:user1) { create(:confirmed_user, :with_home, login: 'permitted_user') }
    let(:project) { user1.home_project }
    let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
    let(:staging_project) { staging_workflow.staging_projects.first }
    let(:staging_owner) { create(:confirmed_user, login: 'staging-hero') }
    let(:staging_project_name) { staging_project.name }
    let(:requester) { create(:confirmed_user, login: 'requester') }
    let(:target_project) { create(:project, name: 'target_project') }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:build_flag_disabled) { staging_project.disabled_for?('build', nil, nil) }
    let!(:target_relationship) { create(:relationship, project: target_project, user: user1) }
    let!(:staging_relationship) { create(:relationship, project: staging_project, user: staging_owner) }
    let!(:staged_request) do
      create(
        :bs_request_with_submit_action,
        review_by_project: staging_project,
        creator: requester,
        description: 'Fixes issue #42',
        target_package: target_package,
        source_package: source_package,
        staging_project: staging_project,
        staging_owner: staging_owner
      )
    end

    before do
      Flipper.enable(:request_index)
      login user
    end

    context 'for staging projects' do
      before do
        visit projects_requests_path(staging_project)
      end

      it 'shows the staging requests' do
        expect(page).to have_link(href: "/request/show/#{staged_request.number}")
      end
    end

    context 'for non staging projects' do
      before do
        visit projects_requests_path(source_project, stage_proj: [staged_request.staging_project.name])
      end

      it 'shows the staging requests' do
        expect(page).to have_link(href: "/request/show/#{staged_request.number}")
      end
    end
  end
end
