RSpec.shared_examples 'bootstrap user tab' do
  let(:user_tab_user) { create(:confirmed_user, login: 'user_tab_user') }
  let!(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:reader) { create(:confirmed_user, login: 'reader_user') }
  # default to prevent "undefined local variable or method `package'" error
  let!(:package) { nil }
  let!(:project) { nil }

  describe 'user roles' do
    let!(:bugowner_user_role) do
      create(:relationship,
             project: project,
             package: package,
             user:    user_tab_user,
             role:    Role.find_by_title('bugowner'))
    end
    let!(:reader_user_role) do
      create(:relationship,
             project: project,
             package: package,
             user:    reader,
             role:    Role.find_by_title('reader'))
    end

    before do
      login user_tab_user
      visit project_path
      click_link('Users')
    end

    scenario 'Viewing user roles' do
      expect(page).to have_text('User Roles')
      expect(find_field('user_maintainer_user_tab_user', visible: false)).to be_checked
      expect(find_field('user_bugowner_user_tab_user', visible: false)).to be_checked
      expect(find_field('user_reviewer_user_tab_user', visible: false)).not_to be_checked
      expect(find_field('user_downloader_user_tab_user', visible: false)).not_to be_checked
      expect(find_field('user_reader_user_tab_user', visible: false)).not_to be_checked
      expect(page).to have_selector('#user-user_tab_user a.remove-user')
    end

    scenario 'Add non existent user' do
      click_link('Add user')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-user-role-modal') do
        fill_in('User:', with: 'Jimmy')
        click_button('Accept')
      end

      expect(page).to have_text("Couldn't find User with login = Jimmy")
    end

    scenario 'Add an existing user' do
      click_link('Add user')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-user-role-modal') do
        fill_in('User:', with: other_user.login)
        click_button('Accept')
      end

      expect(page).to have_text("Added user #{other_user.login} with role maintainer")
      expect(page).to have_text(other_user.realname)
      within('#user-table') do
        # package / project owner plus other user and reader
        expect(find_all('tbody tr').count).to eq(3)
      end

      # Adding a user twice...
      click_link('Add user')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-user-role-modal') do
        fill_in('User:', with: other_user.login)
        click_button('Accept')
      end

      expect(page).to have_text('Relationship already exists')

      click_link('Users')
      within('#user-table') do
        expect(find_all('tbody tr').count).to eq(3)
      end
    end

    scenario 'Remove user from package / project' do
      expect(page).to have_css('a', text: "#{reader.realname} (reader_user)")

      within('#user-reader_user') do
        click_on(class: 'remove-user')
      end
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara
      click_button('Delete')

      expect(page).to have_text('Removed user reader_user')
      expect(page).not_to have_css('a', text: "#{reader.realname} (reader_user)")
    end

    scenario 'Add role to user' do
      # check checkbox
      find_field('user_reviewer_user_tab_user', visible: false).sibling('span').click
      sleep 1 # FIXME: Needed to wait for the Ajax call to perform

      visit project_path
      click_link('Users')
      expect(find_field('user_reviewer_user_tab_user', visible: false)).to be_checked
    end

    scenario 'Remove role from user' do
      # uncheck checkbox
      find_field('user_bugowner_user_tab_user', visible: false).sibling('span').click
      sleep 1 # FIXME: Needed to wait for the Ajax call to perform

      visit project_path
      click_link('Users')
      expect(find_field('user_bugowner_user_tab_user', visible: false)).not_to be_checked
    end
  end

  describe 'group roles' do
    let!(:group) { create(:group, title: 'existing_group') }
    let!(:other_group) { create(:group, title: 'other_group') }
    let!(:maintainer_group_role) { create(:relationship, project: project, package: package, group: group) }
    let!(:bugowner_group_role) do
      create(:relationship,
             project: project,
             package: package,
             group:   group,
             role:    Role.find_by_title('bugowner'))
    end

    before do
      login user_tab_user
      visit project_path
      click_link('Users')
    end

    scenario 'Viewing group roles' do
      expect(page).to have_text('Group Roles')
      expect(find_field('group_maintainer_existing_group', visible: false)).to be_checked
      expect(find_field('group_bugowner_existing_group', visible: false)).to be_checked
      expect(find_field('group_reviewer_existing_group', visible: false)).not_to be_checked
      expect(find_field('group_downloader_existing_group', visible: false)).not_to be_checked
      expect(find_field('group_reader_existing_group', visible: false)).not_to be_checked
      expect(page).to have_selector('#group-existing_group a.remove-group')
    end

    scenario 'Add non existent group' do
      click_link('Add group')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-group-role-modal') do
        fill_in('Group:', with: 'unknown group')
        click_button('Accept')
      end

      expect(page).to have_text("Couldn't find Group 'unknown group'")
    end

    scenario 'Add an existing group' do
      click_link('Add group')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-group-role-modal') do
        fill_in('Group:', with: other_group.title)
        click_button('Accept')
      end

      expect(page).to have_text("Added group #{other_group.title} with role maintainer")
      within('#group-table') do
        # existing group plus new one
        expect(find_all('tbody tr').count).to eq(2)
      end

      # Adding a group twice...
      click_link('Add group')
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-group-role-modal') do
        fill_in('Group:', with: other_group.title)
        click_button('Accept')
      end

      expect(page).to have_text('Relationship already exists')

      click_link('Users')
      within('#group-table') do
        expect(find_all('tbody tr').count).to eq(2)
      end
    end

    scenario 'Add role to group' do
      # check checkbox
      find_field('group_reviewer_existing_group', visible: false).sibling('span').click
      sleep 1 # FIXME: Needed to wait for the Ajax call to perform

      visit project_path
      click_link('Users')
      expect(find_field('group_reviewer_existing_group', visible: false)).to be_checked
    end

    scenario 'Remove role from group' do
      # uncheck checkbox
      find_field('group_bugowner_existing_group', visible: false).sibling('span').click
      sleep 1 # FIXME: Needed to wait for the Ajax call to perform

      visit project_path
      click_link('Users')
      expect(find_field('group_bugowner_existing_group', visible: false)).not_to be_checked
    end
  end
end
