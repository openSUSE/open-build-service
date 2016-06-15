RSpec.shared_examples 'user tab' do
  let!(:user_tab_user) { create(:confirmed_user, login: "user_tab_user") }
  # default to prevent "undefined local variable or method `package'" error
  let!(:package) { nil }
  let!(:project) { nil }

  describe "user roles" do
    let!(:bugowner_user_role) {
      create(:relationship,
             project: project,
             package: package,
             user:    user_tab_user,
             role:    Role.find_by_title('bugowner')
            )
    }

    before do
      login user_tab_user
      visit project_path
      click_link("Users")
    end

    scenario "Viewing user roles" do
      expect(page).to have_text("User Roles")
      expect(find("#user_maintainer_user_tab_user")).to be_checked
      expect(find("#user_bugowner_user_tab_user")).to be_checked
      expect(find("#user_reviewer_user_tab_user")).not_to be_checked
      expect(find("#user_downloader_user_tab_user")).not_to be_checked
      expect(find("#user_reader_user_tab_user")).not_to be_checked
      expect(page).to have_selector("a > img[title='Remove user']")
    end

    scenario "Add role to user" do
      # check checkbox
      find("#user_reviewer_user_tab_user").click

      visit project_path
      click_link("Users")
      expect(find("#user_reviewer_user_tab_user")).to be_checked
    end

    scenario "Remove role from user" do
      # uncheck checkbox
      find("#user_bugowner_user_tab_user").click

      visit project_path
      click_link("Users")
      expect(find("#user_bugowner_user_tab_user")).not_to be_checked
    end
  end

  describe "group roles" do
    let!(:group) { create(:group, title: "existing_group") }
    let!(:maintainer_group_role) { create(:relationship, project: project, package: package, group: group) }
    let!(:bugowner_group_role) {
      create(:relationship,
             project: project,
             package: package,
             group:   group,
             role:    Role.find_by_title('bugowner')
            )
    }

    before do
      login user_tab_user
      visit project_path
      click_link("Users")
    end

    scenario "Viewing group roles" do
      expect(page).to have_text("Group Roles")
      expect(find("#group_maintainer_existing_group")).to be_checked
      expect(find("#group_bugowner_existing_group")).to be_checked
      expect(find("#group_reviewer_existing_group")).not_to be_checked
      expect(find("#group_downloader_existing_group")).not_to be_checked
      expect(find("#group_reader_existing_group")).not_to be_checked
      expect(page).to have_selector("a > img[title='Remove group']")
    end

    scenario "Add role to group" do
      # check checkbox
      find("#group_reviewer_existing_group").click

      visit project_path
      click_link("Users")
      expect(find("#group_reviewer_existing_group")).to be_checked
    end

    scenario "Remove role from group" do
      # uncheck checkbox
      find("#group_bugowner_existing_group").click

      visit project_path
      click_link("Users")
      expect(find("#group_bugowner_existing_group")).not_to be_checked
    end
  end
end
