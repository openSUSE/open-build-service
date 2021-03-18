require 'browser_helper'

RSpec.shared_examples 'a contribution graph' do
  before do
    visit user_path(login: user.login)
  end

  it 'shows contribution graph, only on desktop' do
    if desktop?
      expect(page).to have_text('Contributions')
    else
      expect(page).not_to have_text('Contributions')
    end
  end
end

RSpec.describe 'Bootstrap_User Contributions', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }

  context 'without contribution graph option' do
    it_behaves_like 'a contribution graph'
  end

  context 'with contribution graph disabled' do
    before do
      stub_const('CONFIG', CONFIG.merge('contribution_graph' => :off))
    end

    it 'does not show the contribution table' do
      visit user_path(login: user.login)
      expect(page).not_to have_text('Contributions')
    end
  end

  context 'with contribution graph enabled' do
    before do
      stub_const('CONFIG', CONFIG.merge('contribution_graph' => :on))
    end

    it_behaves_like 'a contribution graph'

    context 'no contributions' do
      it 'shows 0' do
        skip_on_mobile

        visit user_path(login: user.login)
        click_link('Contributions')
        expect(page).to have_text('0 contributions')
      end
    end

    context 'with contributions' do
      let!(:request) { create(:set_bugowner_request, creator: user) }
      let!(:comment) { create(:comment_request, commentable: request, user: user) }
      let!(:review) { create(:review, bs_request: request, reviewer: user, by_user: user, state: :accepted) }

      it 'shows 3' do
        skip_on_mobile

        visit user_path(login: user.login)
        click_link('Contributions')
        expect(page).to have_text('3 contributions')
      end
    end
  end
end
