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

    missing_services = []
    missing_services << "set_version" unless set_version
    missing_services << "download_url" unless download_url
    missing_services << "download_files" unless download_files

    unless missing_services.empty?
      puts "Some tests where skipped, this test suite needs the source services #{missing_services.join(', ')} installed!"
    else
      assert_tag :tag => "service", :attributes => { :name => "set_version" }
      assert_tag :tag => "service", :attributes => { :name => "download_url" }
      assert_tag :tag => "service", :attributes => { :name => "download_files" }
    end
  end

  def test_combine_project_service_list
    prepare_request_with_user "king", "sunflower"

    put "/source/BaseDistro2/_project/_service", '<servicelist> <service name="set_version" /> </servicelist>'
    assert_response :success
    put "/source/BaseDistro2:LinkedUpdateProject/_project/_service", '<servicelist> <service name="download_files" /> </servicelist>'
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "branch"
    assert_response :success
    put "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/_project/_service", '<servicelist> <service name="download_url" /> </servicelist>'
    assert_response :success

    post "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2", :cmd => "getprojectservices"
    assert_response :success

    # cleanup
    prepare_request_with_user "king", "sunflower"
    delete "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject"
    assert_response :success
    delete "/source/BaseDistro2/_project/_service"
    assert_response :success
    delete "/source/BaseDistro2:LinkedUpdateProject/_project/_service"
    assert_response :success
  end

#FIXME: test source service execution

end
