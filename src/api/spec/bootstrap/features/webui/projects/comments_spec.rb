require 'browser_helper'

RSpec.feature 'Comments', type: :feature, js: true do
  scenario 'can be answered' do
    login user
    comment = create(:comment_project, commentable: Project.first, user: user)
    visit project_show_path(user.home_project)
    click_on('Reply')
    fill_in "reply_body_#{comment.id}", with: 'Reply Body'
    click_button("add_reply_#{comment.id}")

    expect(page).to have_text('Reply Body')
  end
end
