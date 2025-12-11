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

      click_link('Create Canned Response')
      fill_in(name: 'canned_response[title]', with: 'wow')
      fill_in(name: 'canned_response[content]', with: 'a canned response')
      click_button('Create')
    end

    it do
      within('#canned-responses') do
        expect(page).to have_css('.card-header', text: 'wow')
        expect(page).to have_css('.card-body', text: 'a canned response')
        expect(page).to have_css('.list-group-item.py-4', text: "Decision's reason: Undefined")
      end
    end
  end

  context 'with an existing canned response' do
    let!(:canned_response) { create(:canned_response, user: user, title: 'wow', content: 'a canned response') }

    before do
      login user
      visit canned_responses_path
    end

    context 'edit an entity' do
      before do
        click_link('Edit')
        fill_in(name: 'canned_response[content]', with: 'another response')
        click_button('Save')
      end

      it 'can be modified' do
        within('#canned-responses') do
          expect(page).to have_no_css('.card-body', text: 'a canned response')
          expect(page).to have_css('.card-body', text: 'another response')
        end
      end
    end

    context 'delete an entity' do
      before do
        within '#canned-responses .card' do
          click_link(title: 'Delete Canned Response')
        end
        within('#delete-canned-response-modal .modal-footer') do
          click_button('Delete')
        end
      end

      it 'can be deleted' do
        expect(page).to have_text 'Canned response was successfully deleted.'
      end

      it 'cannot find deleted entity' do
        within('#canned-responses') do
          expect(page).to have_text('No canned responses yet')
        end
        expect(page).to have_no_text(canned_response.title)
      end
    end
  end

  context 'with decision-related canned response' do
    let(:moderator) { create(:moderator) }

    before do
      Flipper.enable(:content_moderation)
      login moderator
      visit canned_responses_path
      click_link('Create Canned Response')
      fill_in(name: 'canned_response[title]', with: 'wow')
      fill_in(name: 'canned_response[content]', with: 'a decision-related canned response')
      find_by_id('canned_response_decision_type').select('Favored')
      click_button('Create')
    end

    it do
      within('#canned-responses') do
        expect(page).to have_css('.card-header', text: 'wow')
        expect(page).to have_css('.card-body', text: 'a decision-related canned response')
        expect(page).to have_css('.list-group-item.py-4 h5', text: 'Favored')
      end
    end
  end
end
