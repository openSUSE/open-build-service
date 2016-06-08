# encoding: utf-8
require_relative '../../test_helper'

class Webui::DownloadOnDemandControllerTest < Webui::IntegrationTest
  PROJECT_WITH_DOWNLOAD_ON_DEMAND = load_backend_file("download_on_demand/project_with_dod.xml")
  PROJECT_WITHOUT_DOWNLOAD_ON_DEMAND = load_backend_file("download_on_demand/project_without_dod.xml")
  PROJECT_WITH_SEVERAL_DOWNLOAD_ON_DEMAND = load_backend_file("download_on_demand/project_with_several_dod.xml")
  def test_listing_download_on_demand_admin
    use_js

    # Login as admin
    login_king
    visit(project_show_path(project: "home:user5"))

    # Updating via meta
    click_link("Advanced")
    click_link("Meta")
    page.evaluate_script("editors[0].setValue(\"#{PROJECT_WITH_DOWNLOAD_ON_DEMAND.gsub("\n", '\n')}\");")
    click_button("Save")

    find(:id, 'flash-messages').must_have_text('Config successfully saved!')

    click_link("Repositories")
    page.must_have_link 'http://mola.org2'
    page.must_have_text 'rpmmd'

    find(:xpath, "//span[@class='edit-dod-repository-link-container']").must_have_link('Edit')
    find(:xpath, "//span[@class='edit-dod-repository-link-container']").must_have_link('Delete')
  end

  def test_listing_download_on_demand_no_admin
    use_js

    login_tom
    visit(project_show_path(project: "home:tom"))

    click_link("Advanced")
    click_link("Meta")

    page.evaluate_script("editors[0].setValue(\"#{PROJECT_WITH_DOWNLOAD_ON_DEMAND.gsub("\n", '\n').gsub("user5", "tom")}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text('Admin rights are required to change projects using remote resources')
    click_link("Repositories")

    page.wont_have_text 'Download on demand repositories'
    page.wont_have_link 'http://mola.org2'
    page.wont_have_text 'rpmmd'
  end

  def test_adding_download_on_demand # spec/features/webui/projects_spec.rb
    use_js

    # Login as admin
    login_king
    visit(project_repositories_path(project: "home:user5"))
    click_link("Add DoD repository")

    # Fill in the form and send a working dod data
    fill_in("Repository name", with: "My DoD repository")
    select('i586', from: 'Architecture')
    select('rpmmd', from: 'Type')
    fill_in('Url', with: 'http://somerandomurl.es')
    fill_in('Arch. Filter', with: 'i586, noarch')
    fill_in('Master Url', with: 'http://somerandomurl2.es')
    fill_in('SSL Fingerprint', with: '293470239742093')
    fill_in('Public Key', with: 'JLKSDJFSJ83U4902RKLJSDFLJF2J9IJ23OJFKJFSDF')
    click_button('Save')

    find_link("My DoD repository")
    find_link('Add')
    find(".edit-dod-repository-link-container").must_have_link('Edit')
    find(".edit-dod-repository-link-container").must_have_link('Delete')
    page.must_have_link 'http://somerandomurl.es'
    page.must_have_text 'rpmmd'

    click_link("Repositories")
    click_link("Add")

    # Fill in the form and send a not working dod data
    select('x86_64', from: 'Architecture')
    select('rpmmd', from: 'Type')
    fill_in('Url', with: '')
    click_button('Add Download on Demand')
    find(:id, 'flash-messages').must_have_text("Download on Demand can't be created: Validation failed: Url can't be blank")
  end

  def test_editing_download_on_demand # spec/features/webui/projects_spec.rb
    use_js

    # Login as admin
    login_king
    visit(project_show_path(project: "home:user5"))

    # Updating via meta
    click_link("Advanced")
    click_link("Meta")
    page.evaluate_script("editors[0].setValue(\"#{PROJECT_WITH_DOWNLOAD_ON_DEMAND.gsub("\n", '\n')}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text('Config successfully saved!')

    click_link("Repositories")
    within(:css, "span.edit-dod-repository-link-container") do
      click_link("Edit")
    end

    # Fill in the form and send a working dod data
    select('i586', from: 'Architecture')
    select('deb', from: 'Type')
    fill_in('Url', with: 'http://somerandomurl_2.es')
    fill_in('Arch. Filter', with: 'i586, noarch')
    fill_in('Master Url', with: 'http://somerandomurl__2.es')
    fill_in('SSL Fingerprint', with: '33333333444444')
    fill_in('Public Key', with: '902RKLJSDFLJF902RKLJSDFLJF902RKLJSDFLJF')
    click_button('Update Download on Demand')
    find(:id, 'flash-messages').must_have_text('Successfully updated Download on Demand')
    page.must_have_link 'http://somerandomurl_2.es'
    page.must_have_text 'deb'

    click_link("Repositories")
    within(:css, "span.edit-dod-repository-link-container") do
      click_link("Edit")
    end

    # Fill in the form and send a not working dod data
    fill_in('Url', with: '')
    click_button('Update Download on Demand')
    find(:id, 'flash-messages').must_have_text("Download on Demand can't be updated: Validation failed: Url can't be blank")
    page.must_have_link 'http://somerandomurl_2.es'
  end

  def test_destroying_download_on_demand # spec/features/webui/projects_spec.rb
    use_js

    # Login as admin
    login_king
    visit(project_show_path(project: "home:user5"))

    # Updating via meta
    click_link("Advanced")
    click_link("Meta")
    page.evaluate_script("editors[0].setValue(\"#{PROJECT_WITH_SEVERAL_DOWNLOAD_ON_DEMAND.gsub("\n", '\n')}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text('Config successfully saved!')

    click_link("Repositories")
    first(:xpath, "//a[text()='Delete']").click

    page.wont_have_text 'Download on demand repositories'
    page.wont_have_link 'http://mola.org2'
    page.wont_have_text 'rpmmd'
  end
end
