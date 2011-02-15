require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class SourceServicesTest < ActionController::IntegrationTest 
  fixtures :all
  
  def test_get_servicelist
    ActionController::IntegrationTest::reset_auth
    get "/service"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/service"
    assert_response :success
    assert_tag :tag => "servicelist"

    # not using assert_tag for doing a propper error message on missing 
    # source service packages
    download_url = set_version = download_files = nil
    services = ActiveXML::XMLNode.new(@response.body)
    services.each_service do |s|
      if s.name == "download_url"
        download_url = 1
      end
      if s.name == "download_files"
        download_files = 1
      end
      if s.name == "set_version"
        set_version = 1
      end
    end
    puts "This test suite needs the source service \"set_version\" installed !"    unless set_version
#    puts "This test suite needs the source service \"download_url\" installed !"   unless download_url
#    puts "This test suite needs the source service \"download_files\" installed !" unless download_files
  
    assert_tag :tag => "service", :attributes => { :name => "set_version" }
#    assert_tag :tag => "service", :attributes => { :name => "download_url" }
#    assert_tag :tag => "service", :attributes => { :name => "download_files" }
  end

end
