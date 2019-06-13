require 'sphinx_helper'
# For expecting the load of the page to finish we use have_current_path (https://github.com/jnicklas/capybara/blob/master/README.md#navigating)

RSpec.feature 'Search', type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user, :with_home, login: 'titan') }

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
    if is_bento?
      check('project')
      uncheck('package')
    else
      select('Projects', from: 'search_for')
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
    if is_bento?
      check('package')
      uncheck('project')
    else
      select('Packages', from: 'search_for')
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

    if is_bento?
      expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    else
      within('#flash') do
        expect(page).to have_text('Your search did not return any results.')
      end
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

    if is_bento?
      expect(find('#flash-messages')).to have_text('Your search did not return any results.')
    else
      within('#flash') do
        expect(page).to have_text('Your search did not return any results.')
      end
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

    if is_bento?
      expect(find('#flash-messages')).to have_text('You have to search for awesome in something. Click the advanced button...')
    else
      within('#flash') do
        expect(page).to have_text('You have to search for awesome in something. Click the advanced button...')
      end
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

      if is_bento?
        expect(find('#flash-messages')).to have_text('Your search did not return any results.')
      else
        within('#flash') do
          expect(page).to have_text('Your search did not return any results.')
        end
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

  describe 'search for owners' do
    let(:confirmed_user) { create(:confirmed_user, login: 'Thomas') }
    let(:owner_root_project_attrib) { create(:owner_root_project_attrib, project: apache) }
    let(:other_confirmed_user) { create(:confirmed_user, login: 'Tommy') }
    let(:group_bugowner) { create(:group, title: 'bugowner_group') }
    let(:group_maintainer) { create(:group, title: 'maintainer_group') }
    let(:apache_package) { create(:package, name: 'apache2', title: 'Apache2 package', project: apache) }
    let(:relationship_package_user) { create(:relationship_package_user, package: apache_package, user: confirmed_user) }
    let(:relationship_package_group) { create(:relationship_package_group, package: apache_package, group: group_maintainer) }
    let(:relationship_user_bugowner) { create(:relationship_package_user_as_bugowner, package: apache_package, user: other_confirmed_user) }
    let(:relationship_group_bugowner) { create(:relationship_package_group_as_bugowner, package: apache_package, group: group_bugowner) }
    let(:backend_url) { "#{CONFIG['source_url']}/search/published/binary/id?match=(@name='#{apache_package}'+and+(@project='#{apache}'))" }
    let(:backend_response) { file_fixture('apache_search.xml') }

    before do
      stub_request(:post, backend_url).and_return(body: backend_response)
      owner_root_project_attrib
      group_maintainer.add_user(confirmed_user)
      group_bugowner.add_user(other_confirmed_user)
    end

    scenario 'in a package having maintainers/bugowners which are users and groups' do
      relationship_package_user
      relationship_package_group
      relationship_user_bugowner
      relationship_group_bugowner
      reindex_for_search

      login(admin_user)

      visit search_owner_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: apache_package.name
      click_button 'Search'

      within '#search-results' do
        expect(page).to have_text(relationship_package_user.user.name)
        expect(page).to have_text(relationship_package_group.group.title)
        expect(page).to have_text(relationship_user_bugowner.user.name)
        expect(page).to have_text(relationship_group_bugowner.group.title)
      end
    end

    scenario 'in a package having maintainers/bugowners which are only users' do
      relationship_package_user
      relationship_user_bugowner
      reindex_for_search

      login admin_user

      visit search_owner_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: apache_package.name

      click_button 'Search'

      within '#search-results' do
        expect(page).to have_text(relationship_package_user.user.name)
        expect(page).to have_text(relationship_user_bugowner.user.name)
      end
    end

    scenario 'in a package having maintainers/bugowners which are only groups' do
      relationship_package_group
      relationship_group_bugowner
      reindex_for_search

      login admin_user

      visit search_owner_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: apache_package.name
      click_button 'Search'

      within '#search-results' do
        expect(page).to have_text(relationship_package_group.group.title)
        expect(page).to have_text(relationship_group_bugowner.group.title)
      end
    end

    scenario 'in a package without maintainers/bugowners' do
      login admin_user

      visit search_owner_path
      page.evaluate_script('$.fx.off = true;') # Needed to disable javascript animations that can end in not checking the checkboxes properly

      fill_in 'search_input', with: apache_package.name
      click_button 'Search'

      expect(page).not_to have_css('#serach-results')
    end
  end
end
