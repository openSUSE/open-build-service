require 'browser_helper'

RSpec.describe 'SavedReplies', type: :feature, js: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'Rubhan') }
  let(:project) { user.home_project }

  skip 'project show' do # rubocop:disable RSpec/ExampleLength
    create_list(:saved_reply, 3, user: user)
    login user
    visit project_show_path(project: project)
    page.find('#saved-reply-dropdown', visible: :all).click
    replies = page.all('.reply', visible: false)
    expect(replies.size).to eq(3)
  end
end
