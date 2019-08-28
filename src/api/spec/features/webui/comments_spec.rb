require 'browser_helper'

RSpec.feature 'Comments', type: :feature, js: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'burdenski') }
  let!(:comment) { create(:comment_project, commentable: user.home_project, user: user) }

  scenario 'can be created' do
    login user
    visit project_show_path(user.home_project)
    fill_in 'comment_body', with: 'Comment Body'
    find_button('Add comment').click

    expect(page).to have_text('Comment Body')
  end
end
