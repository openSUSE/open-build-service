require 'browser_helper'

RSpec.describe 'SavedReplies', type: :feature, js: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'Rubhan') }
  let(:project) { user.home_project }

  it 'project show' do # rubocop:disable RSpec/ExampleLength
    create_list(:saved_reply, 3, user: user)
    reply = user.saved_replies.first
    login user
    visit project_show_path(project: project)
    find(:id, 'saved-reply-dropdown').click
    expect(find_all(:class, 'reply').length).to eq(3)
    click_on(reply.title)
    expect(find(:id, 'new_comment_body')).to have_text(reply.body)
  end
end
