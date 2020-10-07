require 'browser_helper'

RSpec.describe 'Comment snippets', type: :feature, js: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'burdenski') }

  # rubocop:disable RSpec/ExampleLength
  it 'can be created' do
    login user
    visit comment_snippets_path
    fill_in 'comment_snippet[title]', with: 'Appreciation reply'
    fill_in 'comment_snippet[body]', with: 'Thank you for your contribution.'
    find_button('Add saved reply').click
    visit comment_snippets_path

    expect(page).to have_text('Appreciation reply')
    expect(page).to have_text('Thank you for your contribution.')
  end

  it 'can be deleted' do
    create(:comment_snippet, user: user)
    login user
    visit comment_snippets_path
    click_link('Delete')

    expect(page).to have_text('Please confirm deletion of reply')
    click_button('Delete')

    visit comment_snippets_path
    expect(page).not_to have_text('Appreciation reply')
  end
  # rubocop:enable RSpec/ExampleLength
end
