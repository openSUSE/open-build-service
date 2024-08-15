require 'browser_helper'

RSpec.feature 'Bootstrap_User Contributions', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }

  context 'no contributions' do
    it 'shows 0' do
      visit user_show_path(user: user.login)

      expect(page).to have_text('0 contributions')
    end
  end

  context 'with contributions' do
    let!(:request) { create(:set_bugowner_request, creator: user) }
    let!(:comment) { create(:comment_request, commentable: request, user: user) }
    let!(:review) { create(:review, bs_request: request, reviewer: user, by_user: user, state: :accepted) }

    it 'shows 3' do
      visit user_show_path(user: user.login)
      expect(page).to have_text('3 contributions')
    end
  end
end
