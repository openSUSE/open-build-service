require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApidocsControllerTest < ActionController::IntegrationTest 

  def test_index
    # rails 3 will always go to #index
    visit "/apidocs/" 
    # no interest in comparing with index.html
  end

  def test_subpage
    visit "/apidocs/whatisthis"
    #assert_response 404
    #assert_xml_tag :attributes => { :code => "unknown_file_type" }

    visit "/apidocs/whatisthis.xml"
    #assert_response 404
    #assert_xml_tag :attributes => { :code => "file_not_found" }
    
    visit "/apidocs/project.xml" 
    #assert_response :success
  end

end
