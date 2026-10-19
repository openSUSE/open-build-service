require 'browser_helper'

RSpec.describe 'Vendors', :js, :vcr do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }

  before do
    Flipper.enable(:enhanced_distribution_support)

    login user
  end

  context 'creating a vendor from the project page' do
    before do
      visit project_show_path(project)
      desktop? ? click_link('Create Vendor') : click_menu_link('Actions', 'Create Vendor')

      within('#vendor-form-modal') do
        fill_in('Name', with: 'openSUSE')
        fill_in('Url', with: 'https://opensuse.org')
        click_button('Save')
      end
    end

    it 'creates the vendor' do
      expect(page).to have_text('Vendor was successfully created.')
      expect(project.reload.vendor.name).to eq('openSUSE')
    end

    it 'lands on the vendor page' do
      expect(page).to have_current_path(project_vendor_path(project))
      within('#vendor') { expect(page).to have_text('openSUSE') }
    end
  end

  context 'having an already existing vendor' do
    let!(:vendor) { create(:vendor, project: project, name: 'openSUSE') }
    let!(:distro) { create(:distro, vendor: vendor, name: 'Leap') }

    before do
      distro.distro_releases.create!(name: '15.6')
      visit project_vendor_path(project)
    end

    it 'displays the vendor with its distributions and releases' do
      within('#vendor') do
        expect(page).to have_link('Leap', href: project_distro_path(project, 'Leap'))
        expect(page).to have_link('15.6', href: project_distro_release_path(project, 'Leap', '15.6'))
      end
    end

    context 'editing the vendor through the modal' do
      before do
        within('#vendor') { click_button('Edit') }

        within('#vendor-form-modal') do
          fill_in('Name', with: 'SUSE')
          click_button('Save')
        end
      end

      it 'updates the vendor' do
        expect(page).to have_text('Vendor was successfully updated.')
        expect(vendor.reload.name).to eq('SUSE')
      end
    end

    context 'creating a distro through the new distro modal' do
      before do
        within('#vendor') { click_link('New Distribution') }

        within('#distro-modal--modal') do
          fill_in('Name', with: 'Slowroll')
          fill_in('Url', with: 'https://get.opensuse.org/slowroll')
          click_button('Save')
        end
      end

      it 'creates the distro' do
        expect(page).to have_text('Distro was successfully created.')
        expect(vendor.distros.where(name: 'Slowroll')).to exist
      end
    end

    context 'deleting the vendor' do
      before do
        within('#vendor') { click_button('Delete') }

        within('#delete-vendor-modal') do
          click_button('Remove')
        end
      end

      it 'deletes the vendor' do
        expect(page).to have_text('Vendor was successfully destroyed.')
        expect(project.reload.vendor).to be_nil
      end
    end
  end
end
