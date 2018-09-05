require 'browser_helper'

RSpec.feature 'Bootstrap_Requests', type: :feature, js: true, vcr: true do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }

  context 'for role addition' do
    describe 'for packages' do
      it 'can be submitted' do
        login(submitter)
        visit package_show_path(project: target_project, package: target_package)
        click_link('Request role addition')
        find(:id, 'role').select('Maintainer')
        fill_in('description', with: 'I can produce bugs too.')

        expect { click_button 'Accept' }.to change(BsRequest, :count).by(1)
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants to get the role maintainer " \
                                  "for package #{target_project} / #{target_package}")
        expect(page).to have_css('#description-text', text: 'I can produce bugs too.')
        expect(page).to have_text('In state new')
      end
    end
  end
end
