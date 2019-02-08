require 'browser_helper'

RSpec.feature 'Comments', type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'burdenski') }
  let!(:comment) { create(:comment_project, commentable: user.home_project, user: user) }

  scenario 'can be created' do
    login user
    visit project_show_path(user.home_project)
    fill_in 'comment_body', with: 'Comment Body'
    find_button('Add comment').click

    expect(page).to have_text('Comment Body')
  end

  scenario 'can be answered' do
    skip_if_bootstrap

    login user
    visit project_show_path(user.home_project)

    find('a', text: 'Reply').click
    fill_in("reply_body_#{comment.id}", with: 'Reply Body')
    click_button('Add reply')

    expect(page).to have_text('Reply Body')
  end
end
