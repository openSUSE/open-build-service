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
      let!(:comment) { create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin) }

      before do
        Flipper.enable(:request_show_redesign, admin)
        login admin
        visit request_show_path(bs_request)

        click_on "reply_button_of_#{comment.id}"
        within("#reply_for_#{comment.id}_form") do
          fill_in "reply_for_#{comment.id}_body", with: 'This is a new reply'
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
      Flipper.enable(:request_show_redesign, admin)
      login admin

      visit request_changes_path(bs_request)
      sleep(0.5) # wait for file diff to be loaded
      find_by_id('diff_0_n2').hover # make add comment link visible
      within('#commentdiff_0_n2') do
        find('a', class: 'line-new-comment').click
        sleep(0.5) # wait for comment box to appear
        fill_in 'new_comment_diff_0_n2_body', with: 'My test diff comment'
        find('input[type="submit"]').click
        sleep(0.5) # wait for comment to be created
      end
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
    let!(:comment) { create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin) }

    before do
      login admin
      visit request_show_path(bs_request)
    end

    it 'displays the comment with a hint to the corresponding file and line' do
      expect(page).to have_css('#comments-list', text: "Inline comment for target: 'target_project/package_a', file: 'package_a.changes', and line: 1.")
    end
  end

  describe 'source package file gets altered after inline diff comment was created' do
    let!(:comment) do
      create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin, source_rev: bs_request.bs_request_actions.first.source_rev,
                       target_rev: target_package.dir_hash['srcmd5'])
    end

    before do
      Flipper.enable(:request_show_redesign, admin)
      login admin
      source_package.save_file(file: 'The content of the changes file has completly changed!', filename: "#{source_package.name}.changes", comment: 'No reason, this is just a test...')
      bs_request.bs_request_actions.first.update(source_rev: source_package.dir_hash['srcmd5'])
    end

    context 'changes tab' do
      before do
        visit request_changes_path(bs_request)
      end

      it 'the changes from the altered source package file are displayed in the diff' do
        expect(page).to have_text('The content of the changes file has completly changed!')
      end

      it 'does not display the outdated comment in the changes tab' do
        expect(page).to have_no_text(comment.body)
      end
    end

    context 'conversation tab' do
      before do
        visit request_show_path(bs_request)
      end

      it 'keeps showing the comment in the conversation with a hint that it is outdated' do
        expect(find_by_id("comment-#{comment.id}-bubble")).to have_text(comment.body)
        expect(page).to have_css('span.badge.text-bg-warning', text: 'Outdated')
      end
    end
  end

  describe 'target package gets altered after inline diff comment was created' do
    let!(:comment) do
      create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 2, user: admin, source_rev: bs_request.bs_request_actions.first.source_rev,
                       target_rev: target_package.dir_hash['srcmd5'])
    end

    before do
      Flipper.enable(:request_show_redesign, admin)
      login admin
      target_package.save_file(file: '', filename: "#{target_package.name}.changes", comment: 'No reason, this is just a test...')
    end

    context 'changes tab' do
      before do
        visit request_changes_path(bs_request)
      end

      it 'the changes from the altered target package file are displayed in the diff' do
        expect(page).to have_text("#{target_package.name}.changes")
      end

      it 'does not display the outdated comment in the changes tab' do
        expect(page).to have_no_text(comment.body)
      end
    end

    context 'conversation tab' do
      before do
        visit request_show_path(bs_request)
      end

      it 'keeps showing the comment in the conversation with a hint that it is outdated' do
        expect(find_by_id("comment-#{comment.id}-bubble")).to have_text(comment.body)
        expect(page).to have_css('span.badge.text-bg-warning', text: 'Outdated')
      end
    end
  end
end
