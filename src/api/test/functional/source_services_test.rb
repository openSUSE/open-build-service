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
    puts "This test suite needs the source service \"download_url\" installed !"   unless download_url
    puts "This test suite needs the source service \"download_files\" installed !" unless download_files

    assert_tag :tag => "service", :attributes => { :name => "set_version" }
    assert_tag :tag => "service", :attributes => { :name => "download_url" }
    assert_tag :tag => "service", :attributes => { :name => "download_files" }
  end

  def test_combine_project_service_list
    prepare_request_with_user "king", "sunflower"

    put "/source/BaseDistro2/_project/_service", '<services> <service name="set_version" > <param name="version">0815</param> </service> </services>'
    assert_response :success
    put "/source/BaseDistro2:LinkedUpdateProject/_project/_service", '<services> <service name="download_files" /> </services>'
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "branch"
    assert_response :success
    put "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/_project/_service", '<services> <service name="download_url" > <param name="host">blahfasel</param> </service> </services>'
    assert_response :success

    post "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2", :cmd => "getprojectservices"
    assert_response :success
    assert_tag( :tag => "service", :attributes => { :name => "download_files" } )
    assert_tag( :parent => { :tag => "service", :attributes => { :name => "download_url" } }, :tag => "param", :attributes => { :name => "host"}, :content => "blahfasel" )
    assert_tag( :parent => { :tag => "service", :attributes => { :name => "set_version" } }, :tag => "param", :attributes => { :name => "version"}, :content => "0815" )

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
