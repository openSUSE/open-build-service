require 'sphinx_helper'
# For expecting the load of the page to finish we use have_current_path (https://github.com/jnicklas/capybara/blob/master/README.md#navigating)

RSpec.feature 'Search', type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, login: 'titan') }

  let(:package) { create(:package, name: 'goal', title: 'First goal', project: user.home_project) }
  let(:another_package) { create(:package, name: 'goal2', title: 'Second goal', project: user.home_project) }
  let(:bs_request) { create(:bs_request, description: "This request's description", creator: user) }

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
    click_button 'Search'

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
    if is_bootstrap?
      select('Projects', from: 'search_for')
    else
      check('project')
      uncheck('package')
    end

    click_button 'Search'

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
    if is_bootstrap?
      select('Packages', from: 'search_for')
    else
      check('package')
      uncheck('project')
    end

    check 'title', allow_label_click: true
    click_button 'Search'

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
    check 'title', allow_label_click: true
    uncheck 'name', allow_label_click: true
    uncheck 'description', allow_label_click: true
    click_button 'Search'

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
    uncheck 'title', allow_label_click: true
    uncheck 'name', allow_label_click: true
    check 'description', allow_label_click: true
    click_button 'Search'

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
    click_button 'Search'

    if is_bootstrap?
      within('#flash') do
        expect(page).to have_text('Your search did not return any results.')
      end
    else
      expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    end
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search in no types' do
    skip_if_bootstrap # This specs doesn't make sense in the Bootstrap UI since we search for packages, projects or both.
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    uncheck 'project'
    uncheck 'package'
    click_button 'Search'

    if is_bootstrap?
      within('#flash') do
        expect(page).to have_text('Your search did not return any results.')
      end
    else
      expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    end
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search in no fields' do
    apache2
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'awesome'
    click_button 'Advanced'
    uncheck 'title', allow_label_click: true
    uncheck 'name', allow_label_click: true
    uncheck 'description', allow_label_click: true
    click_button 'Search'

    if is_bootstrap?
      within('#flash') do
        expect(page).to have_text('You have to search for awesome in something. Click the advanced button...')
      end
    else
      expect(find('#flash-messages')).to have_text('You have to search for awesome in something. Click the advanced button...')
    end
    expect(page).to have_selector('#search-results', count: 0)
  end

  scenario 'search Russian project in UTF-8' do
    russian_project
    reindex_for_search

    visit search_path
    page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

    fill_in 'search_input', with: 'вокябюч'
    click_button 'Advanced'
    uncheck 'name', allow_label_click: true
    check 'title', allow_label_click: true
    click_button 'Search'

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
      check 'title', allow_label_click: true
      click_button 'Search'

      if is_bootstrap?
        within('#flash') do
          expect(page).to have_text('Your search did not return any results.')
        end
      else
        expect(find('#flash-messages')).to have_text('Your search did not return any results.')
      end
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
      check 'title', allow_label_click: true
      click_button 'Search'

      within '#search-results' do
        expect(page).to have_link(hidden_package.name)
        expect(page).to have_selector('.search_result', count: 1)
      end
    end
  end
end
