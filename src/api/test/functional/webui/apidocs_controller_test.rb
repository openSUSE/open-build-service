require_relative '../../test_helper'

class Webui::ApidocsControllerTest < Webui::IntegrationTest

  def test_index
    # test relative links
    visit apidocs_path
    first('.request').find(:link, 'Example').click
    assert page.source =~ %r{<title>Open Build Service API</title>}
  end

  def test_subpage
    visit apidocs_file_path(filename: 'whatisthis')
    find('#flash-messages').must_have_text "File not found"

    visit apidocs_file_path(filename: 'project.xml')
    assert page.html =~ %r{project name="superkde"}
  end

  def test_broken_apidocs_setup
    Webui::ApidocsController.any_instance.stubs(:indexpath).returns(nil)
    visit apidocs_path
    page.wont_have_link 'Example'
  end
end
