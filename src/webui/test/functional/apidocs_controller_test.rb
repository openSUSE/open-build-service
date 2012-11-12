require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApidocsControllerTest < ActionDispatch::IntegrationTest 

  def test_index
    # rails 3 will always go to #index
    visit "/apidocs/" 
    # no interest in comparing with index.html
  end

  def test_subpage
    visit "/apidocs/whatisthis"
    assert page.has_text? "A non existing page was requested"

    visit "/apidocs/whatisthis.xml"
    assert page.has_text? "A non existing page was requested"    

    visit "/apidocs/project.xml"
    assert page.html =~ %r{project name="superkde"}
  end

end
