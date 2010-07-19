require File.dirname(__FILE__) + '/../test_helper'

class SearchControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

  def test_search_unknown
    ActionController::IntegrationTest::reset_auth
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 401

    prepare_request_with_user "tscholz", "asdfasdf" 
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 404
    assert_select "status[code] > summary", /no such attribute/
  end

  def test_search_one_maintained_package
    ActionController::IntegrationTest::reset_auth
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response 401

    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response :success
    assert_tag :tag => 'attribute', :attributes => { :name => "Maintained", :namespace => "OBS" }, :children => { :count => 1 }
    assert_tag :child => { :tag => 'project', :attributes => { :name => "Apache"}, :children => { :count => 1 } }
    assert_tag :child => { :child => { :tag => 'package', :attributes => { :name => "apache2" }, :children => { :count => 0 } } }
  end

  def test_xpath_1
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[@name="apache2"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_2
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_3
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="apache2"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_4
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="Testpack"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 0 }
  end
  
  def test_xpath_5
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[devel/@project="kde4"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 0 }
  end

  def test_xpath_6
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="Maintained"]'
    assert_response 400
    assert_select "status[code] > summary", /illegal xpath attribute/
  end

  # >>> Testing HiddenProject - flag "access" set to "disabled"
  def test_search_hidden_project_with_valid_user
    # user is maintainer, thus access to hidden project is allowed
    prepare_request_with_user "adrian", "so_alone"
    get "/search/project", :match => '[@name="HiddenProject"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    #<project name="HiddenProject">
    assert_tag :child => { :tag => 'project', :attributes => { :name => 'HiddenProject'} }
  end
  def test_search_hidden_project_with_invalid_user
    # user is not maintainer - project has to be invisible
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/project", :match => '[@name="HiddenProject"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 0 }
  end
  # <<< Testing HiddenProject - flag "access" set to "disabled"

  # >>> Testing package inside HiddenProject - flag "access" set to "disabled" in Project
  def test_search_package_in_hidden_project_with_valid_user
    # user is maintainer, thus access to hidden package is allowed
    prepare_request_with_user "adrian", "so_alone"
    get "/search/package", :match => '[@name="pack" and @project="HiddenProject"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'pack', :project => "HiddenProject"} }
  end
  def test_search_package_in_hidden_project_with_invalid_user
    # user is not maintainer - package has to be invisible
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/search/package", :match => '[@name="pack" and @project="HiddenProject"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 0 }
  end
  # <<< Testing package inside HiddenProject - flag "access" set to "disabled" in Project

end

