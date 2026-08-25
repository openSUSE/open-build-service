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
      fill_in('Name', with: 'openSUSE')
      fill_in('Url', with: 'https://opensuse.org')
      click_button('Save')
    end

    it 'creates the vendor' do
      expect(page).to have_text('Vendor was successfully created.')
      expect(project.reload.vendor.name).to eq('openSUSE')
    end
  end

  context 'having an already existing vendor' do
    let!(:vendor) { create(:vendor, project: project, name: 'openSUSE') }
    let!(:distro) { create(:distro, vendor: vendor, name: 'Leap') }
    let!(:other_distro) { create(:distro, vendor: vendor, name: 'Tumbleweed') }

    before do
      visit project_vendor_path(project)
    end

    context 'creating a distro through the new distro modal' do
      before do
        click_button('New Distro')

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

    context 'editing a distro through its own modal' do
      before do
        find("button[data-bs-target='#distro-modal-#{distro.id}-modal']").click

        within("#distro-modal-#{distro.id}-modal") do
          fill_in('Name', with: 'Slowroll')
          click_button('Save')
        end
      end

      it 'updates the distro' do
        expect(page).to have_text('Distro was successfully updated.')
        expect(distro.reload.name).to eq('Slowroll')
      end
    end

    context 'deleting a distro through the shared delete modal' do
      before do
        find("a[data-action='#{vendor_distro_path(vendor, distro)}']").click

        within('#delete-distro-modal') do
          click_button('Delete')
        end
      end

      it 'deletes only the distro the modal was opened for' do
        expect(page).to have_text('Distro was successfully destroyed.')
        expect(vendor.distros.reload).to contain_exactly(other_distro)
      end
    end

    it 'deletes the vendor' do
      accept_confirm { find('a[title="Delete"]').click }

      expect(page).to have_text('Vendor was successfully destroyed.')
      expect(project.reload.vendor).to be_nil
    end
  end
end
