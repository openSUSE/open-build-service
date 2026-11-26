require 'browser_helper'

RSpec.describe 'Distros', :js, :vcr do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let(:vendor) { create(:vendor, project: project, name: 'openSUSE') }
  let!(:distro) { create(:distro, vendor: vendor, name: 'Leap') }
  let!(:old_release) { create(:distro_release, distro: distro, name: '15.5') }

  before do
    Flipper.enable(:enhanced_distribution_support)
    create(:distro_release, distro: distro, name: '15.6')

    login user
  end

  context 'visiting the distro page' do
    before do
      visit project_distro_path(project, distro.name)
    end

    it 'shows the distro with a link to its vendor' do
      within('#distro') do
        expect(page).to have_css('h3', text: 'Leap')
        expect(page).to have_link('openSUSE', href: project_vendor_path(project))
      end
    end
  end
end
