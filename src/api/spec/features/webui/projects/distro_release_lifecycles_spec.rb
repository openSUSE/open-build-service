require 'browser_helper'

RSpec.describe 'Distro release lifecycles', :js do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let(:vendor) { create(:vendor, project: project, name: 'openSUSE') }
  let(:distro) { create(:distro, vendor: vendor, name: 'Leap') }
  let(:distro_release) { create(:distro_release, distro: distro, name: '16.0') }

  before do
    create(:distro_release_lifecycle, distro_release: distro_release, name: 'Retired', date: Date.new(2030, 1, 1), status: :end_of_life)
    create(:distro_release_lifecycle, distro_release: distro_release, name: 'First beta', date: Date.new(2026, 1, 1), status: :beta)
  end

  context 'as a project maintainer' do
    before do
      login user
      visit project_distro_release_path(project.name, distro.name, distro_release.name)
    end

    it 'lists the lifecycles with the earliest date first' do
      expect(page).to have_text(/First beta.*Beta.*Retired.*End of Life/m)
    end

    context 'adding a lifecycle' do
      before do
        click_button('New Lifecycle')

        within("#distro-release-#{distro_release.id}-new-lifecycle-modal") do
          fill_in('Name', with: 'Final')
          fill_in('Date', with: Date.new(2026, 6, 1))
          select('General Availability', from: 'Status')
          click_button('Save')
        end
      end

      it 'creates the lifecycle' do
        expect(page).to have_text('Lifecycle was successfully created.')
        expect(distro_release.distro_release_lifecycles.find_by(name: 'Final'))
          .to have_attributes(date: Date.new(2026, 6, 1), status: 'general_availability')
      end

      it 'shows the new lifecycle in date order' do
        expect(page).to have_text(/First beta.*Final.*General Availability.*Retired/m)
      end
    end
  end

  context 'as a user without permission' do
    let(:other_user) { create(:confirmed_user, login: 'John') }

    before do
      login other_user
      visit project_distro_release_path(project.name, distro.name, distro_release.name)
    end

    it 'shows the lifecycles' do
      expect(page).to have_text('First beta')
      expect(page).to have_text('Retired')
    end

    it 'does not offer to add a lifecycle' do
      expect(page).to have_no_button('New Lifecycle')
    end
  end
end
