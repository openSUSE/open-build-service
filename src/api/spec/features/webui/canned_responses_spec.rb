require 'browser_helper'

RSpec.describe 'Canned responses', :js do
  let(:user) { create(:confirmed_user, login: 'burdenski') }

  before do
    Flipper.enable(:canned_responses)
  end

  context 'can be created' do
    before do
      login user
      visit canned_responses_path
    end

    it do
      fill_in(name: 'canned_response[title]', with: 'wow')
      fill_in(name: 'canned_response[content]', with: 'a canned response')
      click_button('Create')
      find('.accordion-button').click

      expect(page).to have_text('a canned response')
    end
  end

  context 'with an existing canned response' do
    let!(:canned_response) { create(:canned_response, user: user, title: 'wow', content: 'a canned response') }

    before do
      login user
      visit canned_responses_path
      find('.accordion-button').click
    end

    it 'can be modified' do
      click_link('Edit')
      fill_in(name: 'canned_response[content]', with: 'another response')
      click_button('Save')
      find('.accordion-button').click

      expect(page).to have_text('another response')
    end

    it 'can be deleted' do
      accept_confirm do
        click_button('Delete')
      end

      expect(page).to have_no_text('wow')
    end
  end

  context 'with decision-related canned response' do
    let(:moderator) { create(:moderator) }

    before do
      Flipper.enable(:content_moderation)
      login moderator
      visit canned_responses_path
      fill_in(name: 'canned_response[title]', with: 'wow')
      fill_in(name: 'canned_response[content]', with: 'a decision-related canned response')
      find_by_id('canned_response_decision_type').select('Favored')
      click_button('Create')
      find('.accordion-button').click
    end

    it { expect(page).to have_text('Favored') }
    it { expect(page).to have_text('a decision-related canned response') }
  end
end
