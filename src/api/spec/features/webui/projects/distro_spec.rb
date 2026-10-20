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
        expect(page).to have_link('openSUSE', href: project_show_path(project, anchor: 'vendor'))
      end
    end

    it 'selects the newest release' do
      within('#distro-release') { expect(page).to have_text('Leap 15.6') }
    end

    context 'selecting another release' do
      before do
        within('#distro-releases-list') { click_link('15.5') }
      end

      it 'shows the details of the selected release' do
        within('#distro-release') { expect(page).to have_text('Leap 15.5') }
      end

      it 'updates the URL' do
        expect(page).to have_current_path(project_distro_release_path(project, distro.name, '15.5'))
      end
    end

    context 'editing the distro through the modal' do
      before do
        within('#distro') { click_button('Edit') }

        within('#distro-form-modal') do
          fill_in('Name', with: 'Leap Micro')
          click_button('Save')
        end
      end

      it 'updates the distro' do
        expect(page).to have_text('Distro was successfully updated.')
        expect(distro.reload.name).to eq('Leap Micro')
      end
    end

    context 'deleting the distro' do
      before do
        within('#distro') { click_button('Delete') }

        within('#delete-distro-modal') do
          click_button('Remove')
        end
      end

      it 'deletes the distro' do
        expect(page).to have_text('Distro was successfully destroyed.')
        expect(vendor.distros).to be_empty
      end
    end
  end

  context 'visiting a release page' do
    before do
      visit project_distro_release_path(project, distro.name, old_release.name)
    end

    it 'shows the distro page with the release selected' do
      within('#distro-releases-list') { expect(page).to have_css('a.active', text: '15.5') }
      within('#distro-release') { expect(page).to have_text('Leap 15.5') }
    end

    context 'deleting the release' do
      before do
        within('#distro-release') { click_button('Delete') }

        within('#delete-distro-release-modal') do
          click_button('Remove')
        end
      end

      it 'deletes the release' do
        expect(page).to have_text('Release was successfully destroyed.')
        expect(distro.distro_releases.pluck(:name)).to eq(['15.6'])
      end
    end
  end
end
