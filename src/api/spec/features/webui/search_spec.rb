# frozen_string_literal: true
require 'sphinx_helper'
# For expecting the load of the page to finish we use have_current_path (https://github.com/jnicklas/capybara/blob/master/README.md#navigating)

RSpec.feature 'Search', type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'titan') }

  let(:package) { create(:package, name: 'goal', title: 'First goal', project_id: user.home_project.id) }
  let(:another_package) { create(:package, name: 'goal2', title: 'Second goal', project_id: user.home_project.id) }
  let(:bs_request) { create(:bs_request, description: "This request's description", creator: user.login) }

  let(:apache) { create(:project, name: 'Apache', title: 'Awesome project', description: 'Very awesome project') }
  let(:apache2) { create(:project, name: "#{apache.name}:Apache2", title: 'New and awesome project', description: 'Very very very awesome project') }
  let(:apache2_subproject) { create(:project, name: "#{apache2.name}:FakeSubproject") }

  let(:russian_project) { create(:project, name: 'Russian', title: 'Этёам вокябюч еюж эи') }
  let(:chinese_project) { create(:project, name: 'Chinese', title: '窞綆腤 埱娵徖 渮湸湤 殠 唲堔') }

  let(:hidden_project) { create(:forbidden_project, name: 'SecretProject', title: 'Fake description') }
  let(:hidden_package) { create(:package, name: 'hidden_package', title: 'Hidden package rocks!', project_id: hidden_project.id) }

  scenario 'basic search functionality' do
    package
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: package.name
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(user.home_project_name)
      expect(page).to have_link(package.name)
    end
  end

  scenario 'search for projects and subprojects' do
    apache2_subproject
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: apache2.name
    click_button 'Advanced'
    check 'project'
    uncheck 'package'
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(apache2.name)
      expect(page).to have_link(apache2_subproject.name)
      expect(page).to have_selector('.search_result', count: 2)
    end
  end

  scenario 'search for packages only' do
    package
    another_package
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'goal'
    click_button 'Advanced'
    check 'package'
    uncheck 'project'
    check 'title'
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(user.home_project_name)
      expect(page).to have_link(package.name)
      expect(page).to have_link(another_package.name)
      expect(page).to have_selector('.search_result', count: 2)
    end
  end

  scenario 'search by title only' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    check 'title'
    uncheck 'name'
    uncheck 'description'
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(apache.name)
      expect(page).to have_link(apache2.name)
      expect(page).to have_selector('.search_result', count: 2)
    end
  end

  scenario 'search by description only' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    uncheck 'title'
    uncheck 'name'
    check 'description'
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(apache.name)
      expect(page).to have_link(apache2.name)
      expect(page).to have_selector('.search_result', count: 2)
    end
  end

  scenario 'search for non existent things' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'fooo'
    click_button 'search_button'

    expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search in no types' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    uncheck 'project'
    uncheck 'package'
    click_button 'search_button'

    expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search in no fields' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    uncheck 'title'
    uncheck 'name'
    uncheck 'description'
    click_button 'search_button'

    expect(find('#flash-messages')).to have_text('You have to search for awesome in something. Click the advanced button...')
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search Russian project in UTF-8' do
    russian_project
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'вокябюч'
    click_button 'Advanced'
    uncheck 'name'
    check 'title'
    click_button 'search_button'

    within '#search-results' do
      expect(page).to have_link(russian_project.name)
      expect(page).to have_selector('.search_result', count: 1)
    end
  end

  describe 'search for hidden project' do
    scenario 'as anonymous user' do
      hidden_package
      create(:relationship_project_user, project: hidden_project, user: user)
      reindex_for_search

      visit search_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: 'hidden'
      click_button 'Advanced'
      check 'title'
      click_button 'search_button'

      expect(find('#flash-messages')).to have_text('Your search did not return any results.')
      expect(page).to have_selector('#search-results', count: 0)
    end

    scenario 'as admin user' do
      hidden_package
      create(:relationship_project_user, project: hidden_project, user: user)
      reindex_for_search

      login admin_user

      visit search_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: 'hidden'
      click_button 'Advanced'
      check 'title'
      click_button 'search_button'

      within '#search-results' do
        expect(page).to have_link(hidden_package.name)
        expect(page).to have_selector('.search_result', count: 1)
      end
    end
  end
end
