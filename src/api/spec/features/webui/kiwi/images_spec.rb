require 'browser_helper'

RSpec.describe 'Kiwi_Images', :js, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }
  let(:kiwi_image) { create(:kiwi_image_with_package, with_kiwi_file: true, project: project, package_name: 'package_with_kiwi_file') }

  before do
    login(user)
    visit(package_show_path(project: project, package: kiwi_image.package))
  end

  context 'project with wiki image' do
    it 'modify author' do
      skip 'Capybara is not waiting for the Ajax request to finish'
      click_link('View Image')

      click_link('Details')
      click_link('Edit details')
      fill_in 'kiwi_image_description_attributes_author', with: 'custom_author'
      click_link('Continue')
      find_by_id('kiwi-image-update-form-save').click

      within('#kiwi-description') do
        expect(page).to have_text('Author: custom_author')
      end
    end
  end

  context 'software tab' do
    let(:repository) { create(:repository, name: 'openSUSE_Tumbleweed', project: project, architectures: ['x86_64']) }
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{project}/_availablebinaries?path=#{project}/#{repository}" }
    let(:package_response) do
      <<~XML
        <availablebinaries>
          <packages>
            <arch>noarch</arch>
            <name>perl-Citrix</name>
          </packages>
        </availablebinaries>
      XML
    end
    let(:other_backend_url) { "#{CONFIG['source_url']}/_command?prpa=#{project}/#{repository}/x86_64&cmd=availablebinaries" }
    let(:available) do
      <<~XML
        {"perl-Citrix"=>["noarch"] }
      XML
    end

    before do
      repository
      stub_request(:get, backend_url).and_return(body: package_response)
      stub_request(:post, other_backend_url).and_return(body: available)
    end

    it 'add repository and package' do
      skip 'Capybara is not waiting for the Ajax request to finish'
      click_link('View Image')
      click_link('Software')
      click_link('Add repository')

      within('#add-repository-') do
        fill_in('add_repo_kiwi_target_project', with: project)
        first('.ui-menu-item-wrapper').click
        click_link('Continue')
      end

      click_link('Add package')

      within('#add-package') do
        fill_in('Name', with: 'perl')
        first('.ui-menu-item-wrapper').click
        click_link('Continue')
      end

      find_by_id('kiwi-image-update-form-save').click
      find_by_id('image-name')
      click_link('Software')

      within('#kiwi-repositories-list') do
        expect(page).to have_text("#{repository}@#{project}")
      end

      within('#kiwi-packages-list') do
        expect(page).to have_text('perl-Citrix')
      end
    end

    it 'edit respository' do
      skip 'Capybara is not waiting for the Ajax request to finish'
      click_link('View Image')
      click_link('Software')
      click_link('Add repository')

      within('#add-repository-') do
        fill_in('add_repo_kiwi_target_project', with: project)
        first('.ui-menu-item-wrapper').click
        click_link('Continue')
      end

      within('#kiwi-repositories-list') do
        expect(page).to have_text("#{repository}@#{project}")
      end

      click_link("#{repository}@#{project}")

      within('#add-repository-') do
        fill_in('alias_for_repo', with: 'custom-alias')
        click_link('Continue')
      end

      find_by_id('kiwi-image-update-form-save').click
      find_by_id('image-name')
      click_link('Software')

      within('#kiwi-repositories-list') do
        expect(page).to have_text('custom-alias')
      end
    end

    it 'edit package' do
      skip 'Capybara is not waiting for the Ajax request to finish'
      click_link('View Image')
      click_link('Software')
      click_link('Add repository')

      within('#add-repository-') do
        fill_in('add_repo_kiwi_target_project', with: project)
        first('.ui-menu-item-wrapper').click
        click_link('Continue')
      end

      click_link('Add package')

      within('#add-package') do
        fill_in('Name', with: 'perl')
        first('.ui-menu-item-wrapper').click
        click_link('Continue')
      end

      click_link('perl-Citrix')

      within('#package-perl-Citrix') do
        fill_in('Arch:', with: 'x86_64')
        click_link('Continue')
      end

      find_by_id('kiwi-image-update-form-save').click
      find_by_id('image-name')
      click_link('Software')

      find_by_id('kiwi-packages-list')
      within('#kiwi-packages-list') do
        expect(page).to have_text('perl-Citrix')
        expect(page).to have_css('a small', text: '(x86_64)')
      end
    end
  end
end
