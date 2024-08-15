require 'browser_helper'

RSpec.feature 'Comments', type: :feature, js: true, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'burdenski') }
  let!(:comment) { create(:comment_project, commentable: user.home_project, user: user) }
  let!(:old_comment_text) { comment.body }

  scenario 'answering comments' do
    login user
    visit project_show_path(user.home_project)

    click_button('Reply')
    within('.media') do
      fill_in(placeholder: 'Add a new comment (markdown markup supported)', with: 'Reply Body')
      click_button('Add comment')
    end

    visit project_show_path(user.home_project)
    expect(page).to have_text('Reply Body')
  end

  scenario 'can be deleted' do
    login user
    visit project_show_path(user.home_project)

    within('.media') do
      find('a', text: 'Delete').click
    end

    expect(page).to have_text('Please confirm deletion of comment')
    click_button('Delete')

    visit project_show_path(user.home_project)
    expect(page).not_to have_text(old_comment_text)
  end
end
