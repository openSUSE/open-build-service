require 'browser_helper'

RSpec.describe 'Comments with diff', :js, :vcr do
  let(:admin) { create(:admin_user, login: 'Admin') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) do
    create(:package_with_files,
           name: 'package_a',
           project: source_project,
           changes_file_content: '- Fixes ------')
  end
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end

  let!(:comment) { create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1, user: admin) }

  context 'reply comment' do
    describe 'when under the beta program' do
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
        expect(page).to have_text('target_project/target_package > package_a.changes')
      end
    end
  end
end
