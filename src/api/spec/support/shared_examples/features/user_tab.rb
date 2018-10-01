RSpec.shared_examples 'user tab' do
  let!(:other_user) { create(:confirmed_user, login: 'other_user') }
  let!(:user_tab_user) { create(:confirmed_user, login: 'user_tab_user') }
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
      expect(find('#user_maintainer_user_tab_user')).to be_checked
      expect(find('#user_bugowner_user_tab_user')).to be_checked
      expect(find('#user_reviewer_user_tab_user')).not_to be_checked
      expect(find('#user_downloader_user_tab_user')).not_to be_checked
      expect(find('#user_reader_user_tab_user')).not_to be_checked
      expect(page).to have_selector("a > img[title='Remove user']")
    end

    scenario 'Add user to package / project' do
      click_link('Add user')
      fill_in('User:', with: 'Jimmy')
      click_button('Add user')
      expect(page).to have_text("Couldn't find User with login = Jimmy")

      fill_in('User:', with: other_user.login)
      click_button('Add user')
      expect(page).to have_text("Added user #{other_user.login} with role maintainer")
      within('#user-table') do
        # package / project owner plus other user and reader
        expect(find_all('tbody tr').count).to eq(3)
      end

      # Adding a user twice...
      click_link('Add user')
      fill_in('User:', with: other_user.login)
      click_button('Add user')
      expect(page).to have_text('Relationship already exists')
      click_link('Users')
      within('#user-table') do
        expect(find_all('tbody tr').count).to eq(3)
      end
    end

    scenario 'Remove user from package / project' do
      expect(page).to have_css('a', text: "#{reader.realname} (reader_user)")
      accept_alert do
        find('#user-reader_user a.remove-user').click
      end
      expect(page).to have_text('Removed user reader_user')
      expect(page).not_to have_css('a', text: "#{reader.realname} (reader_user)")
    end

    scenario 'Add role to user' do
      # check checkbox
      find('#user_reviewer_user_tab_user').click

      visit project_path
      click_link('Users')
      expect(find('#user_reviewer_user_tab_user')).to be_checked
    end

    scenario 'Remove role from user' do
      # uncheck checkbox
      find('#user_bugowner_user_tab_user').click

      visit project_path
      click_link('Users')
      expect(find('#user_bugowner_user_tab_user')).not_to be_checked
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
      expect(find('#group_maintainer_existing_group')).to be_checked
      expect(find('#group_bugowner_existing_group')).to be_checked
      expect(find('#group_reviewer_existing_group')).not_to be_checked
      expect(find('#group_downloader_existing_group')).not_to be_checked
      expect(find('#group_reader_existing_group')).not_to be_checked
      expect(page).to have_selector("a > img[title='Remove group']")
    end

    scenario 'Add group to package / project' do
      click_link('Add group')
      fill_in('Group:', with: 'unknown group')
      click_button('Add group')
      expect(page).to have_text("Couldn't find Group 'unknown group'")

      fill_in('Group:', with: other_group.title)
      click_button('Add group')
      expect(page).to have_text("Added group #{other_group.title} with role maintainer")
      within('#group-table') do
        # existing group plus new one
        expect(find_all('tbody tr').count).to eq(2)
      end

      # Adding a group twice...
      click_link('Add group')
      fill_in('Group:', with: other_group.title)
      click_button('Add group')
      expect(page).to have_text('Relationship already exists')
      click_link('Users')
      within('#group-table') do
        expect(find_all('tbody tr').count).to eq(2)
      end
    end

    scenario 'Add role to group' do
      # check checkbox
      find('#group_reviewer_existing_group').click

      visit project_path
      click_link('Users')
      expect(find('#group_reviewer_existing_group')).to be_checked
    end

    scenario 'Remove role from group' do
      # uncheck checkbox
      find('#group_bugowner_existing_group').click

      visit project_path
      click_link('Users')
      expect(find('#group_bugowner_existing_group')).not_to be_checked
    end
  end
end
