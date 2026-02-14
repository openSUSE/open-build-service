require 'spec_helper'

RSpec.describe 'layouts/webui/_top_navigation.html.haml' do
  let(:user) { create(:confirmed_user) }

  before do
    allow(view).to receive(:current_user).and_return(nil)
    allow(User).to receive(:session).and_return(nil)
    allow(Configuration).to receive(:logo).and_return(double(attached?: false))
    # Mocking render calls to avoid rendering inner partials if they cause issues,
    # but we want to see the icon which is in the main partial.
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with(partial: 'layouts/webui/top_navigation_search').and_return('SEARCH_BOX')
    allow(view).to receive(:render).with(partial: 'layouts/webui/top_navigation_nobody').and_return('NOBODY_NAV')
    allow(view).to receive(:render).with(hash_including(partial: 'layouts/webui/unread_notifications_counter'))
                                   .and_return('NOTIFICATIONS')
    allow(view).to receive(:render).with(any_args).and_call_original
  end

  it 'displays the help link to the manual' do
    render

    expect(rendered).to have_link(nil, href: 'https://openbuildservice.org/help/manuals/')
    expect(rendered).to have_css('i.fas.fa-question-circle')
  end

  it 'displays the help text' do
    render

    expect(rendered).to have_content('Help')
  end

  context 'when user is logged in' do
    before do
      allow(User).to receive(:session).and_return(user)
    end

    it 'displays the help link to the manual' do
      render

      expect(rendered).to have_link(nil, href: 'https://openbuildservice.org/help/manuals/')
      expect(rendered).to have_css('i.fas.fa-question-circle')
    end

    it 'displays the help text' do
      render

      expect(rendered).to have_content('Help')
    end
  end
end
