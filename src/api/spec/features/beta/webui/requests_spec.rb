require 'browser_helper'

RSpec.describe 'Requests', :vcr do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:target_project) { receiver.home_project }

  context 'a user requests a role addition on a project' do
    before do
      login submitter
      visit project_show_path(project: target_project)
      desktop? ? click_on('Request Role Addition') : click_menu_link('Actions', 'Request Role Addition')
      choose 'Bugowner'
      choose 'User'
      fill_in 'User:', with: submitter.login.to_s
      fill_in 'Description:', with: 'I can fix bugs too.'
    end

    it 'can be submitted' do
      click_button('Request')

      expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants to get the role bugowner for project #{target_project}")
      expect(page).to have_css('#description-text', text: 'I can fix bugs too.')
      expect(page).to have_css('.badge', text: 'new')
      expect(BsRequest.where(creator: submitter.login, description: 'I can fix bugs too.')).to exist
    end
  end
end
