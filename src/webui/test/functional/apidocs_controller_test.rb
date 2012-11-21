require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApidocsControllerTest < ActionDispatch::IntegrationTest 

  def test_index
    # test relative links
    visit "/apidocs" 
    first('.request').find(:link, 'Example').click
    assert page.source =~ %r{<title>Open Build Service API</title>}
  end

  def test_subpage
    visit "/apidocs/whatisthis"
    assert find('#flash-messages').has_text? "File not found"

    visit "/apidocs/project.xml"
    assert page.html =~ %r{project name="superkde"}
  end

end
