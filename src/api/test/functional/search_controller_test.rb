require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class SearchControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

  def test_search_unknown
    reset_auth
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf" 
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 404
    assert_select "status[code] > summary", /no such attribute/
  end

  def test_search_one_maintained_package
    reset_auth
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response :success
    assert_xml_tag :tag => 'attribute', :attributes => { :name => "Maintained", :namespace => "OBS" }, :children => { :count => 1 }
    assert_xml_tag :child => { :tag => 'project', :attributes => { :name => "Apache"}, :children => { :count => 1 } }
    assert_xml_tag :child => { :child => { :tag => 'package', :attributes => { :name => "apache2" }, :children => { :count => 0 } } }
  end

  def test_xpath_1
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[@name="apache2"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_2
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_3
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="apache2"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_4
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="Testpack"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }
  end
  
  def test_xpath_5
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[devel/@project="kde4"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }
  end

  def test_xpath_6
    prepare_request_with_user "Iggy", "asdfasdf"
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
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }
    #<project name="HiddenProject">
    assert_xml_tag :child => { :tag => 'project', :attributes => { :name => 'HiddenProject'} }
  end
  def test_search_hidden_project_with_invalid_user
    # user is not maintainer - project has to be invisible
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/project", :match => '[@name="HiddenProject"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }
  end
  # <<< Testing HiddenProject - flag "access" set to "disabled"

  # >>> Testing package inside HiddenProject - flag "access" set to "disabled" in Project
  def test_search_package_in_hidden_project_with_valid_user
    # user is maintainer, thus access to hidden package is allowed
    prepare_request_with_user "adrian", "so_alone"
    get "/search/package", :match => '[@name="pack" and @project="HiddenProject"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'pack', :project => "HiddenProject"} }
  end
  def test_search_package_in_hidden_project_as_non_maintainer
    # user is not maintainer - package has to be invisible
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package", :match => '[@name="pack" and @project="HiddenProject"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }

    get "/search/package", :match => '[@name="pack"]'
    assert_response :success
    assert_xml_tag :tag => 'package', :attributes => { :project => "SourceprotectedProject", :name => "pack" }
    assert_no_xml_tag :tag => 'package', :attributes => { :project => "HiddenProject", :name => "pack" }
  end
  # <<< Testing package inside HiddenProject - flag "access" set to "disabled" in Project

  def get_repos
    ret = Array.new
    col = ActiveXML::Base.new @response.body
    col.each_repository do |r|
      ret << "#{r.project}/#{r.name}"
    end
    return ret
  end

  def test_search_issues
    prepare_request_with_user "Iggy", "asdfasdf" 
    get "/search/issue", :match => '[@name="123456"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'name', :content => "123456"
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'tracker', :content => "bnc"
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'label', :content => "bnc#123456"
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'state', :content => "CLOSED"
    assert_xml_tag :parent => { :tag => 'owner'}, :tag => 'login', :content => "fred"

    get "/search/issue", :match => '[@name="123456" and @tracker="bnc"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'label', :content => "bnc#123456"

    # opposite order to test database joins
    get "/search/issue", :match => '[@tracker="bnc" and @name="123456"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'label', :content => "bnc#123456"

    get "/search/issue", :match => '[@name="0123456" and @tracker="bnc"]'
    assert_response :success
    assert_no_xml_tag :tag => 'issue'

    get "/search/issue", :match => '[@tracker="bnc" and (@name="123456" or @name="1234")]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 2 }

    get "/search/issue", :match => '[@tracker="bnc" and (@name="123456" or @name="1234") and @state="CLOSED"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 1 }

    get "/search/issue", :match => '[owner/@login="fred"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'label', :content => "bnc#123456"

    get "/search/issue", :match => '[owner/@email="fred@feuerstein.de"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue'}, :tag => 'label', :content => "bnc#123456"
  end

  def test_search_repository_id
    prepare_request_with_user "Iggy", "asdfasdf" 
    get "/search/repository/id"
    assert_response :success
    assert_xml_tag :tag => 'collection'
    repos = get_repos
    assert repos.include?('home:Iggy/10.2')
    assert !repos.include?('HiddenProject/nada'), "HiddenProject repos public"

    prepare_request_with_user "king", "sunflower" 
    get "/search/repository/id"
    assert_response :success
    assert_xml_tag :tag => 'collection'
    repos = get_repos
    assert repos.include?('home:Iggy/10.2')
    assert repos.include?('HiddenProject/nada'), "HiddenProject repos public"
  end

  def test_search_request
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/request", match: "(action/target/@package='pack2' and action/target/@project='BaseDistro2.0' and action/source/@project='BaseDistro2.0' and action/source/@package='pack2_linked' and action/@type='submit')"
    assert_response :success
  end

  def get_package_count
    return ActiveXML::Base.new(@response.body).each_package.length
  end

  def test_pagination
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package"
    assert_response :success
    assert_xml_tag :tag => 'collection'
    all_packages_count = get_package_count

    get "/search/package", :limit => 3
    assert_response :success
    assert_xml_tag :tag => 'collection'
    assert get_package_count == 3

    get "/search/package", :offset => 3
    assert_response :success
    assert_xml_tag :tag => 'collection'
    assert get_package_count == (all_packages_count - 3)
  end

end

