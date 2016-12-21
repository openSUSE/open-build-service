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
end
