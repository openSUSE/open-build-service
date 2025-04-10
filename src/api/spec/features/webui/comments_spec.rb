require 'browser_helper'

RSpec.describe 'Comments', :js, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'burdenski') }
  let!(:comment) { create(:comment_project, commentable: user.home_project, user: user) }
  let!(:old_comment_text) { comment.body }

  it 'can be created' do
    login user
    visit project_show_path(user.home_project)
    fill_in 'new_comment_body', with: 'Comment Body'
    find_button('Add comment').click

    expect(page).to have_text('Comment Body')
  end

  it 'can be created using canned responses' do
    Flipper.enable(:canned_responses)
    login user
    create(:canned_response, user: user, title: 'test reply', content: 'This is a canned response')
    visit project_show_path(user.home_project)
    fill_in(placeholder: 'Write your comment here... (Markdown markup is supported)', with: 'Reply Body')
    find_button('Canned Responses').click
    find('li', text: 'test reply').click
    find_button('Add comment').click

    expect(page).to have_text('This is a canned response')
  end

  it 'answering comments' do
    login user
    visit project_show_path(user.home_project)

    click_button('Reply')
    within('.comment') do
      fill_in(placeholder: 'Write your comment here... (Markdown markup is supported)', with: 'Reply Body')
      click_button('Add comment')
    end

    visit project_show_path(user.home_project)
    expect(page).to have_text('Reply Body')
  end

  it 'can be deleted' do
    login user
    visit project_show_path(user.home_project)

    within('.comment') do
      find('a', text: 'Delete').click
    end

    expect(page).to have_text('Please confirm deletion of comment')
    click_button('Delete')

    visit project_show_path(user.home_project)
    expect(page).to have_no_text(old_comment_text)
  end
end
