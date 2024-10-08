RSpec.shared_examples 'bootstrap user tab' do
  let(:user_tab_user) { create(:confirmed_user, :with_home, login: 'user_tab_user') }
  let!(:other_user) { create(:confirmed_user, :with_home, login: 'other_user') }
  let(:reader) { create(:confirmed_user, login: 'reader_user') }
  # default to prevent "undefined local variable or method `package'" error
  let!(:package) { nil }
  let!(:project) { nil }

  describe 'user roles' do
    let!(:bugowner_user_role) do
      create(:relationship,
             project: project,
             package: package,
             user: user_tab_user,
             role: Role.find_by_title('bugowner'))
    end
    let!(:reader_user_role) do
      create(:relationship,
             project: project,
             package: package,
             user: reader,
             role: Role.find_by_title('reader'))
    end

    before do
      login user_tab_user
      visit project_path
      click_link('Users')
    end

    it 'Viewing user roles' do
      skip_on_mobile

      expect(page).to have_text('User Roles')
      expect(find_field('user_maintainer_user_tab_user', visible: false)).to be_checked
      expect(find_field('user_bugowner_user_tab_user', visible: false)).to be_checked
      expect(find_field('user_reviewer_user_tab_user', visible: false)).not_to be_checked
      expect(find_field('user_downloader_user_tab_user', visible: false)).not_to be_checked
      expect(find_field('user_reader_user_tab_user', visible: false)).not_to be_checked
      expect(page).to have_css("a.remove-user[data-object='user_tab_user']")
    end

    it 'Add non existent user' do
      skip_on_mobile

      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-user').click
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-user-role-modal') do
        fill_in('User:', with: 'Jimmy')
        click_button('Accept')
      end

      expect(page).to have_text("Couldn't find User with login = Jimmy")
    end

    it 'Add an existing user' do
      skip_on_mobile

      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-user').click
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
      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-user').click
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

    it 'Remove user from package / project' do
      skip_on_mobile

      find('td', text: "#{reader.realname} (reader_user)").ancestor('tr').find('.remove-user').click
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara
      click_button('Remove')

      expect(page).to have_text('Removed user reader_user')
      expect(page).to have_no_css('a', text: "#{reader.realname} (reader_user)")
    end

    it 'Add role to user' do
      skip_on_mobile

      toggle_checkbox('user_reviewer_user_tab_user')

      visit project_path # project_users_path
      click_link('Users')
      expect(find_field('user_reviewer_user_tab_user', visible: false)).to be_checked
    end

    it 'Remove role from user' do
      skip_on_mobile

      toggle_checkbox('user_bugowner_user_tab_user')

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
             group: group,
             role: Role.find_by_title('bugowner'))
    end

    before do
      login user_tab_user
      visit project_path
      click_link('Users')
    end

    it 'Viewing group roles' do
      skip_on_mobile

      expect(page).to have_text('Group Roles')
      expect(find_field('group_maintainer_existing_group', visible: false)).to be_checked
      expect(find_field('group_bugowner_existing_group', visible: false)).to be_checked
      expect(find_field('group_reviewer_existing_group', visible: false)).not_to be_checked
      expect(find_field('group_downloader_existing_group', visible: false)).not_to be_checked
      expect(find_field('group_reader_existing_group', visible: false)).not_to be_checked
      expect(page).to have_css("a.remove-group[data-object='existing_group']")
    end

    it 'Add non existent group' do
      skip_on_mobile

      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-group').click
      sleep 1 # FIXME: Needed to avoid a flickering test because the animation of the modal is sometimes faster than capybara

      within('#add-group-role-modal') do
        fill_in('Group:', with: 'unknown group')
        click_button('Accept')
      end

      expect(page).to have_text("Couldn't find Group")
    end

    it 'Add an existing group' do
      skip_on_mobile

      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-group').click
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
      # FIXME: on mobile, when `screen-offset-top` CSS rule is in place, scrolling and clicking at capybara level does not work
      find_by_id('add-group').click
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

    it 'Add role to group' do
      skip_on_mobile

      toggle_checkbox('group_reviewer_existing_group')

      visit project_path
      click_link('Users')
      expect(find_by_id('group_reviewer_existing_group', visible: false)).to be_checked
    end

    it 'Remove role from group' do
      skip_on_mobile

      toggle_checkbox('group_bugowner_existing_group')

      visit project_path
      click_link('Users')
      expect(find_field('group_bugowner_existing_group', visible: false)).not_to be_checked
    end
  end
end
