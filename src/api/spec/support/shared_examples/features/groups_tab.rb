RSpec.shared_examples 'user tab' do
  let!(:group) { create(:group, title: "existing_group") }
  let!(:group_tab_user) { create(:confirmed_user, login: "group_tab_user") }
  # default to prevent "undefined local variable or method `package'" error
  let(:package) { nil }
  let(:project) { nil }
  let!(:relationship_maintainer) {
    create(:relationship_project_group,
           project: project,
           package: package,
           group:   group
          )
  }
  let!(:relationship_bugowner) {
    create(:relationship_project_group,
           project: project,
           package: package,
           group:   group,
           role:    Role.find_by_title('bugowner')
          )
  }
  let(:project_path) { project_show_path(project: group_tab_user.home_project_name) }

  before do
    login group_tab_user
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
