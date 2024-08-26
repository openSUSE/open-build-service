require 'browser_helper'

RSpec.describe 'Reports', :js, :vcr do
  before do
    Flipper.enable(:content_moderation)
  end

  def fill_and_submit_report_form(report_comment_author: false)
    within('#report-modal') do
      find_by_id('report_category_other').click
      fill_in id: 'report_reason', with: 'This is not okay!'
      check('report_comment_author') if report_comment_author
      click_button('Submit')
    end
  end

  describe 'reporting a comment on a project' do
    let(:project) { create(:project, name: 'some_random_project') }

    context 'for a user who is not the author' do
      let(:user) { create(:confirmed_user, login: 'jane_doe') }
      let!(:comment) { create(:comment, commentable: project) }

      before do
        login user
        visit project_show_path(project)
      end

      it 'displays the "You reported this comment." message instantly' do
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment reported successfully') }
      end

      it 'is possible to report both the comment and its author' do
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form(report_comment_author: true)
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment and its author both reported successfully') }
      end
    end

    context 'for a user who is the author' do
      let(:author) { create(:confirmed_user, login: 'foo') }
      let!(:comment) { create(:comment, commentable: project, user: author) }

      before do
        login author
        visit project_show_path(project)
      end

      it 'does not display the report link' do
        within('div#comments') { expect(page).to have_no_link('Report') }
      end
    end
  end

  describe 'reporting a comment on a package' do
    let(:project) { create(:project, name: 'some_random_project') }
    let(:package) { create(:package, project: project, name: 'some_random_package') }

    context 'for a user who is not the author' do
      let(:user) { create(:confirmed_user, login: 'jane_doe') }
      let!(:comment) { create(:comment, commentable: package) }

      before do
        login user
        visit package_show_path(project, package)
      end

      it 'displays the "You reported this comment." message instantly' do
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment reported successfully') }
      end

      it 'is possible to report the both the comment and its author' do
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form(report_comment_author: true)
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment and its author both reported successfully') }
      end
    end

    context 'for a user who is the author' do
      let(:author) { create(:confirmed_user, login: 'foo') }
      let!(:comment) { create(:comment, commentable: package, user: author) }

      before do
        login author
        visit package_show_path(project, package)
      end

      it 'does not display the report link' do
        within('div#comments') { expect(page).to have_no_link('Report') }
      end
    end
  end

  describe 'reporting a comment on a request' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:project) { create(:project, name: 'some_random_project') }
    let(:bs_request) { create(:delete_bs_request, target_project: project, description: 'Delete this project!', creator: user) }

    context 'for a user who is not the author' do
      let!(:comment) { create(:comment, commentable: bs_request) }

      before do
        login user
        visit request_show_path(bs_request)
      end

      it 'displays the "You reported this comment." message instantly' do
        click_link(id: "comment-#{comment.id}-dropdown-toggle")
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment reported successfully') }
      end

      it 'is possible to report the both the comment and its author' do
        click_link(id: "comment-#{comment.id}-dropdown-toggle")
        click_link('Report', id: "js-comment-#{comment.id}")
        fill_and_submit_report_form(report_comment_author: true)
        expect(page).to have_text('You reported this comment.')
        within('#flash') { expect(page).to have_text('Comment and its author both reported successfully') }
      end
    end

    context 'for a user who is the author' do
      let(:author) { create(:confirmed_user, login: 'foo') }
      let!(:comment) { create(:comment, commentable: bs_request, user: author) }

      before do
        login author
        visit request_show_path(bs_request)
      end

      it 'does not display the report link' do
        within('div.comments-thread') { expect(page).to have_no_link('Report') }
      end
    end
  end

  describe 'reporting a project' do
    context 'for a user who is not a maintainer' do
      let(:user) { create(:confirmed_user, login: 'jane_doe') }
      let(:project) { create(:project, name: 'some_random_project') }

      before do
        login user
        visit project_show_path(project)
      end

      it 'displays the "You reported this project." message instantly' do
        desktop? ? click_link('Report Project') : click_menu_link('Actions', 'Report Project')
        expect(page).to have_no_text('Report the author of the comment')
        fill_and_submit_report_form
        expect(page).to have_text('You reported this project.')
      end
    end

    context 'for a user who is a maintainer' do
      let(:maintainer) { create(:confirmed_user, login: 'foo') }
      let(:project) { create(:project, name: 'some_random_project', maintainer: maintainer) }

      before do
        login maintainer
        visit project_show_path(project)
      end

      it 'does not display the report link' do
        click_link('Actions') if mobile?
        expect(page).to have_no_link('Report Project')
      end
    end
  end

  describe 'reporting a package' do
    let(:project) { create(:project, name: 'some_random_project') }
    let(:package) { create(:package, project: project, name: 'some_random_package') }

    context 'for a user who is not a maintainer' do
      let(:user) { create(:confirmed_user, login: 'jane_doe') }
      let(:package) { create(:package, project: project, name: 'some_random_package') }

      before do
        login user
        visit package_show_path(project, package)
      end

      it 'displays the "You reported this package." message instantly' do
        desktop? ? click_link('Report Package') : click_menu_link('Actions', 'Report Package')
        expect(page).to have_no_text('Report the author of the comment')
        fill_and_submit_report_form
        expect(page).to have_text('You reported this package.')
      end
    end

    context 'for a user who is maintainer' do
      let(:maintainer) { create(:confirmed_user, login: 'foo') }
      let(:package) { create(:package_with_maintainer, project: project, name: 'some_random_package', maintainer: maintainer) }

      before do
        login maintainer
        visit package_show_path(project, package)
      end

      it 'does not display the report link' do
        click_link('Actions') if mobile?
        expect(page).to have_no_link('Report Package')
      end
    end
  end

  describe 'reporting a user' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }

    context 'for a user visiting another users page' do
      let(:another_user) { create(:confirmed_user) }

      before do
        login user
        visit user_path(another_user)
      end

      it 'displays the "You reported this user." message instantly' do
        click_link('Report', id: "js-user-#{another_user.id}")
        expect(page).to have_no_text('Report the author of the comment')
        fill_and_submit_report_form
        expect(page).to have_text('You reported this user.')
      end
    end

    context 'for a user visiting their own users page' do
      before do
        login user
        visit user_path(user)
      end

      it 'does not display the report link' do
        within('div.basic-info') { expect(page).to have_no_link('Report') }
      end
    end
  end
end
