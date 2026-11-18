require 'browser_helper'

RSpec.describe 'Distro releases', :js do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let(:vendor) { create(:vendor, project: project, name: 'openSUSE') }
  let(:distro) { create(:distro, vendor: vendor, name: 'Leap') }

  before do
    Flipper.enable(:enhanced_distribution_support)
  end

  context 'as a project maintainer' do
    before do
      login user
    end

    context 'creating a release from the distro page' do
      before do
        visit project_distro_path(project.name, distro.name)
        find("a[href='#{new_project_distro_release_path(project.name, distro.name)}']").click

        fill_in('Name', with: '16.0')
        fill_in('distro_release[description]', with: 'The next Leap')
        fill_in('Url', with: 'https://get.opensuse.org/leap/16.0')
        click_button('Save')
      end

      it 'creates the release' do
        expect(page).to have_text('Release was successfully created.')
        expect(distro.distro_releases.find_by(name: '16.0'))
          .to have_attributes(description: 'The next Leap', url: 'https://get.opensuse.org/leap/16.0')
      end

      it 'shows the release on the distro page' do
        expect(page).to have_link('16.0', href: project_distro_release_path(project.name, distro.name, '16.0'))
      end
    end

    context 'having existing releases' do
      let!(:distro_release) { create(:distro_release, distro: distro, name: '16.0', description: 'The next Leap') }
      let!(:other_distro_release) { create(:distro_release, distro: distro, name: '15.6') }

      context 'editing a release from the distro page' do
        before do
          visit project_distro_release_path(project.name, distro.name, distro_release.name)
          within('#distro-release') { click_link('Edit') }

          fill_in('distro_release[description]', with: 'The current Leap')
          click_button('Save')
        end

        it 'updates the release' do
          expect(page).to have_text('Release was successfully updated.')
          expect(distro_release.reload.description).to eq('The current Leap')
        end
      end

      context 'deleting a release through the shared delete modal' do
        before do
          visit project_distro_release_path(project.name, distro.name, distro_release.name)
          within('#distro-release') { click_button('Delete') }
        end

        it 'names the release and the distro in the modal' do
          within('#delete-distro-release-modal') do
            expect(page).to have_text("Please confirm deletion of the release '16.0' of the distribution 'Leap'.")
          end
        end

        it 'deletes only the release the modal was opened for' do
          within('#delete-distro-release-modal') do
            click_button('Remove')
          end

          expect(page).to have_text('Release was successfully destroyed.')
          expect(distro.distro_releases.reload).to contain_exactly(other_distro_release)
        end
      end
    end
  end

  context 'viewing a release' do
    let(:repository) { create(:repository, project: project, name: 'openSUSE_Leap_16.0') }
    let!(:distro_release) do
      create(:distro_release, distro: distro, name: '16.0', description: 'The next Leap', url: 'https://get.opensuse.org/leap',
                              repositories: [repository], architectures: [Architecture.find_by_name('x86_64')])
    end

    before do
      login user
      visit project_distro_release_path(project.name, distro.name, distro_release.name)
    end

    it 'shows the release details' do
      within('#distro-release') { expect(page).to have_css('h4', text: 'Leap 16.0') }
      expect(page).to have_text('The next Leap')
      expect(page).to have_link('https://get.opensuse.org/leap')
    end

    it 'shows the repositories with their architectures' do
      within('#distro-release-repositories') do
        expect(page).to have_text("#{project.name}/openSUSE_Leap_16.0")
        expect(page).to have_css('.badge', text: 'x86_64')
      end
    end
  end

  context 'as a user without permission' do
    let(:other_user) { create(:confirmed_user, login: 'John') }
    let!(:distro_release) { create(:distro_release, distro: distro, name: '16.0') }

    before do
      login other_user
    end

    it 'does not offer to add, edit or delete releases on the distro page' do
      visit project_distro_path(project.name, distro.name)

      expect(page).to have_link('16.0')
      expect(page).to have_no_css("a[href='#{new_project_distro_release_path(project.name, distro.name)}']")
      expect(page).to have_no_css("a[href='#{edit_project_distro_release_path(project.name, distro.name, distro_release.name)}']")
      expect(page).to have_no_button('Delete')
    end

    it 'does not offer to edit or delete the release on its show page' do
      visit project_distro_release_path(project.name, distro.name, distro_release.name)

      within('#distro-release') { expect(page).to have_css('h4', text: 'Leap 16.0') }
      expect(page).to have_no_link('Edit')
      expect(page).to have_no_button('Edit')
      expect(page).to have_no_button('Delete')
    end
  end
end
