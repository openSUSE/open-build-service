require 'browser_helper'

RSpec.describe 'Repositories', :js do
  let(:admin_user) { create(:admin_user) }
  let!(:repository) { create(:repository) }

  describe 'DoD Repositories' do
    let(:project_with_dod_repo) { create(:project) }
    let(:repository) { create(:repository, project: project_with_dod_repo) }
    let!(:repo_arch) { create(:repository_architecture, repository: repository, architecture: Architecture.find_by_name('armv7l')) }
    let!(:download_repository_source) { create(:download_repository, repository: repository) }
    let!(:download_repository_source2) { create(:download_repository, repository: repository, arch: 'armv7l') }
    let(:dod_repository) { download_repository_source.repository }

    before do
      login admin_user
    end

    it 'add DoD repositories' do
      visit(project_repositories_path(project: admin_user.home_project_name))
      click_link('Add DoD Repository')
      fill_in('Repository name', with: 'My DoD repository')
      select('i586', from: 'Architecture')
      select('rpmmd', from: 'Type')
      fill_in('Url', with: 'http://somerandomurl.es')
      fill_in('Arch. Filter', with: 'i586, noarch')
      fill_in('Master Url', with: 'http://somerandomurl2.es')
      fill_in('SSL Fingerprint', with: '293470239742093')
      fill_in('Public Key', with: 'JLKSDJFSJ83U4902RKLJSDFLJF2J9IJ23OJFKJFSDF')
      click_button('Accept')

      expect(page).to have_css('#repositories > .card')

      within '#repositories > .card' do
        expect(page).to have_link('My DoD repository')
        expect(page).to have_link('Add Download on Demand Source')
        expect(page).to have_link('Delete Repository')
        # DoD source
        expect(page).to have_text('i586')
        expect(page).to have_link('http://somerandomurl.es')
        expect(page).to have_text('rpmmd')
        expect(page).to have_text('Download on demand sources')
        expect(page).to have_link('Edit Download on Demand Source')
        expect(page).to have_link('Delete Download on Demand Source')
      end
    end

    it 'delete DoD repositories' do
      visit(project_repositories_path(project: project_with_dod_repo))
      within '#repositories > .card' do
        click_link(title: 'Delete Repository')
      end

      expect(find_by_id('delete-repository'))
        .to have_text("Please confirm deletion of '#{dod_repository}' repository")

      within('#delete-repository .modal-footer') do
        click_button('Delete')
      end

      expect(page).to have_text 'Successfully removed repository'
      expect(project_with_dod_repo.repositories).to be_empty
    end

    it 'edit download repositories' do
      visit(project_repositories_path(project: project_with_dod_repo))
      within '#repositories > .card' do
        find("[data-bs-target='#edit-dod-source-modal-#{download_repository_source}']").click
      end

      within("#edit-dod-source-modal-#{download_repository_source}") do
        select('i586', from: 'Architecture')
        select('deb', from: 'Type')
        fill_in('Url', with: 'http://some_random_url_2.es')
        fill_in('Arch. Filter', with: 'i586, noarch')
        fill_in('Master Url', with: 'http://some_other_url.es')
        fill_in('SSL Fingerprint', with: 'test')
        fill_in('Public Key', with: 'some_key')
        click_button('Accept')
      end

      expect(page).to have_text 'Successfully updated Download on Demand'
      download_repository_source.reload

      expect(download_repository_source.arch).to eq('i586')
      expect(download_repository_source.repotype).to eq('deb')
      expect(download_repository_source.url).to eq('http://some_random_url_2.es')
      expect(download_repository_source.archfilter).to eq('i586, noarch')
      expect(download_repository_source.masterurl).to eq('http://some_other_url.es')
      expect(download_repository_source.mastersslfingerprint).to eq('test')
      expect(download_repository_source.pubkey).to eq('some_key')
    end

    it 'delete download repository sources' do
      visit(project_repositories_path(project: project_with_dod_repo))
      within '#repositories > .card' do
        find("[data-bs-target='#delete-dod-source-modal-#{download_repository_source}']").click
      end

      expect(find("#delete-dod-source-modal-#{download_repository_source}"))
        .to have_text("Please confirm deletion of '#{download_repository_source.arch}' Download on Demand")

      within("#delete-dod-source-modal-#{download_repository_source} .modal-footer") do
        click_button('Delete')
      end
      expect(page).to have_text 'Successfully removed Download on Demand'
      expect(repository.download_repositories.count).to eq(1)

      within '#repositories > .card' do
        find("[data-bs-target='#delete-dod-source-modal-#{download_repository_source2}']").click
      end

      expect(find("#delete-dod-source-modal-#{download_repository_source2}"))
        .to have_text("Please confirm deletion of '#{download_repository_source2.arch}' Download on Demand")

      within("#delete-dod-source-modal-#{download_repository_source2} .modal-footer") do
        click_button('Delete')
      end

      expect(page).to have_text "Download on Demand can't be removed: DoD Repositories must have at least one repository."
      expect(repository.download_repositories.count).to eq(1)
    end

    it 'add DoD repositories via meta editor' do
      project_with_dod_xml = file_fixture('project_with_dod.xml').read.gsub('user5', admin_user.login)

      visit(project_meta_path(project_name: admin_user.home_project_name))
      page.evaluate_script("editors[0].setValue(\"#{project_with_dod_xml.gsub("\n", '\n')}\");")
      click_button('Save')
      expect(page).to have_css('#flash', text: 'Config successfully saved!')

      visit(project_repositories_path(project: admin_user.home_project_name))
      within '#repositories > .card' do
        expect(page).to have_link('standard')
        expect(page).to have_link('Add Download on Demand Source')
        expect(page).to have_link('Delete Repository')
        # DoD source
        expect(page).to have_text('x86_64')
        expect(page).to have_link('http://mola.org2')
        expect(page).to have_text('rpmmd')
        expect(page).to have_text('Download on demand sources')
        expect(page).to have_link('Edit Download on Demand Source')
        expect(page).to have_link('Delete Download on Demand Source')
      end
    end
  end

  describe 'Repositories Flags' do
    let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
    let(:project) { user.home_project }

    it_behaves_like 'bootstrap tests for sections with flag tables'
  end

  describe 'Repositories' do
    before do
      login admin_user

      fake_distribution_body = file_fixture('distributions.xml').read

      stub_request(:get, 'https://api.opensuse.org/public/distributions.xml')
        .to_return(status: 200, body: fake_distribution_body, headers: {})
    end

    it 'add/delete repository from distribution' do
      # Create interconnect
      visit(new_interconnect_path(project: admin_user.home_project))
      click_button('Connect', match: :first)
      expect(page).to have_text('Connected')

      visit(new_project_distribution_path(project_name: admin_user.home_project))
      distribution = Distribution.find_by(reponame: 'openSUSE_Tumbleweed')
      find("label[for='distribution-#{distribution.id}-checkbox']").click
      wait_for_ajax

      visit(project_repositories_path(project: admin_user.home_project))

      expect(page).to have_css('#repositories > .card')

      within '#repositories > .card' do
        expect(page).to have_link('openSUSE_Tumbleweed')
      end

      visit(new_project_distribution_path(project_name: admin_user.home_project))
      find("label[for='distribution-#{distribution.id}-checkbox']").click
      wait_for_ajax

      visit(project_repositories_path(project: admin_user.home_project))

      expect(page).to have_no_css('#repositories > .card')
    end

    it 'add repository from project' do
      visit(project_repositories_path(project: admin_user.home_project))

      click_link('Add from a Project')
      fill_in('add_repo_from_project_target_project', with: repository.project)
      # Select the first autocomplete result
      first('.ui-menu-item-wrapper').click
      # Remove focus from autocomplete. Needed to trigger update of the other input fields.
      find_by_id('target_repo').click

      click_button('Accept')

      expect(page).to have_css('#repositories > .card')

      within '#repositories > .card' do
        expect(page).to have_link("#{repository.project}_#{repository}")
        expect(page).to have_link('Edit Repository')
        expect(page).to have_link('Add Repository Path')
        expect(page).to have_link('Download Repository')
        expect(page).to have_link('Delete Repository')
        # Repository path
        expect(page).to have_text("#{repository.project}/#{repository}")
      end
    end
  end
end
