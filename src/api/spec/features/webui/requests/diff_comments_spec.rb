require 'browser_helper'

RSpec.describe 'Comments with diff', :js, :vcr do
  let(:admin) { create(:admin_user, login: 'Admin') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package_with_changes_file, name: 'package_a', project: target_project, changes_file_content: 'Different content then source package changes file!') }
  let(:source_package) do
    create(:package_with_changes_file,
           name: 'package_a',
           project: source_project)
  end
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package,
           source_rev: source_package.dir_hash['srcmd5'])
  end

  context 'reply comment' do
    describe 'when under the beta program' do
      let!(:comment) do
        admin.run_as do
          create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin)
        end
      end

      before do
        Flipper.enable(:request_show_redesign, admin)
        login admin
        visit request_show_path(bs_request)

        click_on "reply_button_of_#{comment.id}"
        within("#reply_for_#{comment.id}_form") do
          fill_in "reply_for_#{comment.id}_body-textarea", with: 'This is a new reply'
          click_on 'Add comment'
        end
      end

      it 'displays the changes after adding a new comment' do
        expect(page).to have_text('This is a new reply')
        expect(page).to have_text('target_project/package_a > package_a.changes')
      end
    end
  end

  describe 'create diff comment' do
    before do
      # It's not possible to hover over a line to wait for the comment box to appear while in mobile
      skip('This scenario is not posible under mobile') if mobile?

      Flipper.enable(:request_show_redesign, admin)
      login admin

      visit request_changes_path(bs_request)
      # Wait for the file diff to be loaded
      # See diff_list_component.html.haml:6 to understand why the id looks like this
      find_by_id('diff-list-package_a-changes').visible?
      find_by_id('diff_0_n2').hover # make add comment link visible
      within('#commentdiff_0_n2') do
        find('a', class: 'line-new-comment').click
        # Wait for comment box to appear
        find_by_id('new_comment_diff_0_n2_form').visible?
        fill_in 'new_comment_diff_0_n2_body-textarea', with: 'My test diff comment'
        find('input[type="submit"]').click
      end
      # Wait for the comment to be created and appear back
      find('.comment-bubble-content').visible?
    end

    it 'displays the comment on the file diff in the changes tab' do
      expect(page).to have_css("#comment-#{Comment.last.id}-body", text: 'My test diff comment')
    end

    it 'displays the comment in the conversation tab' do
      visit request_show_path(bs_request)
      expect(page).to have_css("#comment-#{Comment.last.id}-body", text: 'My test diff comment')
      expect(page).to have_css("#comment-#{Comment.last.id}-bubble", text: 'target_project/package_a > package_a.changes')
    end
  end

  describe 'diff comment in legacy view' do
    before do
      login admin
      create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin)
      visit request_show_path(bs_request)
    end

    it 'displays the comment with a hint to the corresponding file and line' do
      expect(page).to have_css('#comments-list', text: "Inline comment for target: 'target_project/package_a', file: 'package_a.changes', and line: 1.")
    end
  end
end
