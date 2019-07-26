require 'browser_helper'

RSpec.describe 'Bootstrap_User Contributions', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }

  context 'without contribution graph option' do
    it 'shows the contribution graph' do
      visit user_path(login: user.login)
      expect(page).to have_css('#contributors-table')
    end
  end

  context 'with contribution graph disabled' do
    before do
      stub_const('CONFIG', CONFIG.merge('contribution_graph' => :off))
    end

    it 'does not show the contribution table' do
      visit user_path(login: user.login)
      expect(page).not_to have_css('#contributors-table')
    end
  end

  context 'with contribution graph enabled' do
    before do
      stub_const('CONFIG', CONFIG.merge('contribution_graph' => :on))
    end

    it 'shows the contribution graph' do
      visit user_path(login: user.login)
      expect(page).to have_css('#contributors-table')
    end

    context 'no contributions' do
      it 'shows 0' do
        visit user_path(login: user.login)

        expect(page).to have_text('0 contributions')
      end
    end

    context 'with contributions' do
      let!(:request) { create(:set_bugowner_request, creator: user) }
      let!(:comment) { create(:comment_request, commentable: request, user: user) }
      let!(:review) { create(:review, bs_request: request, reviewer: user, by_user: user, state: :accepted) }

      before do
        visit user_path(login: user.login)
      end

      it 'shows 3' do
        expect(page).to have_text('3 contributions')
      end

      it 'renders single day contributions' do
        expect(page).to have_css('td.activity-percentil1')
        find('td.activity-percentil1').click
        expect(page.text).to match(/Contributions on .*\n1 request created\n1\n1 review done\nin requests: 1\n1 comment written/)
      end
    end
  end
end
