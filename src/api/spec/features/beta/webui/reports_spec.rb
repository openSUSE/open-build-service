require 'browser_helper'

RSpec.describe 'Reports', :js, :vcr do
  before do
    Flipper.enable(:content_moderation)
  end

  describe 'after reporting a comment on a project' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }
    let!(:comment) { create(:comment, commentable: project) }

    before do
      login user
      visit project_show_path(project)
    end

    it 'displays the "You reported this comment." message instantly' do
      click_link('Report', id: "js-comment-#{comment.id}")
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this comment.')
    end
  end

  describe 'after reporting a comment on a package' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }
    let(:package) { create(:package, project: project, name: 'some_random_package') }
    let!(:comment) { create(:comment, commentable: package) }

    before do
      login user
      visit package_show_path(project, package)
    end

    it 'displays the "You reported this comment." message instantly' do
      click_link('Report', id: "js-comment-#{comment.id}")
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this comment.')
    end
  end

  describe 'after reporting a comment on a request' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }
    let(:bs_request) { create(:delete_bs_request, target_project: project, description: 'Delete this project!', creator: user) }
    let!(:comment) { create(:comment, commentable: bs_request) }

    before do
      login user
      visit request_show_path(bs_request)
    end

    it 'displays the "You reported this comment." message instantly' do
      click_link('Report', id: "js-comment-#{comment.id}")
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this comment.')
    end
  end

  describe 'after reporting a project' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }

    before do
      login user
      visit project_show_path(project)
    end

    it 'displays the "You reported this project." message instantly' do
      desktop? ? click_link('Report Project') : click_menu_link('Actions', 'Report Project')
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this project.')
    end
  end

  describe 'after reporting a package' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }
    let(:package) { create(:package, project: project, name: 'some_random_package') }

    before do
      login user
      visit package_show_path(project, package)
    end

    it 'displays the "You reported this package." message instantly' do
      desktop? ? click_link('Report Package') : click_menu_link('Actions', 'Report Package')
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this package.')
    end
  end

  describe 'after reporting a user' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:another_user) { create(:confirmed_user) }

    before do
      login user
      visit user_path(another_user)
    end

    it 'displays the "You reported this user." message instantly' do
      click_link('Report', id: "js-user-#{another_user.id}")
      within('#report-modal') { click_button('Submit') }
      expect(page).to have_text('You reported this user.')
    end
  end
end
