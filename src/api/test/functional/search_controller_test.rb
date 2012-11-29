require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class SearchControllerTest < ActionController::IntegrationTest 
  
  fixtures :all

  def setup
    super
    wait_for_scheduler_start
  end

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

    get "/search/package/id", :match => '[contains(@name,"Test")]'
    assert_response :success
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'TestPack', :project => "home:Iggy"} }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'ToBeDeletedTestPack', :project => "home:Iggy"} }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'test', :project => "CopyTest"} }
    assert_xml_tag :tag => 'collection', :children => { :count => 3 }
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
    assert_xml_tag :tag => 'collection', :attributes => { :matches => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
    get "/search/package/id", :match => '[attribute/@name="OBS:Maintained" and @name="apache2"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :attributes => { :matches => 1 }
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

  def test_xpath_old_osc
    # old osc < 0.137 did use the search interface wrong, but that worked ... :/
    # FIXME3.0: to be removed!
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/package_id", :match => '[attribute/@name="OBS:Maintained" and @name="apache2"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :attributes => { :matches => 1 }
    assert_xml_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
    get "/search/project_id", :match => '[@name="kde"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :attributes => { :matches => 1 }
    assert_xml_tag :child => { :tag => 'project', :attributes => { :name => 'kde' } }
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
    col = ActiveXML::Node.new @response.body
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

  def test_osc_search_devel_package_after_request_accept
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/search/package", match: "([devel/[@project='Devel:BaseDistro:Update' and @package='pack2']])"
    assert_response :success
    assert_xml_tag :tag => 'collection', :attributes => { :matches => 1 }
    assert_xml_tag :tag => 'package', :attributes => { :project => "BaseDistro:Update", :name => "pack2" }
  end

  def test_search_request
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/search/request", match: "(action/target/@package='pack2' and action/target/@project='BaseDistro2.0' and action/source/@project='BaseDistro2.0' and action/source/@package='pack2_linked' and action/@type='submit')"
    assert_response :success

    # what osc may do
    get "search/request", match: "(state/@name='new' or state/@name='review') and (action/target/@project='BaseDistro2.0' or submit/target/@project='BaseDistro2.0' or action/source/@project='BaseDistro2.0' or submit/source/@project='BaseDistro2.0') and (action/target/@package='pack2_linked' or submit/target/@package='pack2_linked' or action/source/@package='pack2_linked' or submit/source/@package='pack2_linked')"
    assert_response :success

    # what osc really is doing
    get "search/request", match: "(state/@name='new' or state/@name='review') and (target/@project='BaseDistro2.0' or source/@project='BaseDistro2.0') and (target/@package='pack2_linked' or source/@package='pack2_linked')"
    assert_response :success

    # maintenance team is doing this query
    get "search/request", :match => "state/@name='review' and review[@by_group='maintenance-team' and @state='new']"
    assert_response :success

    get "search/request", match: "(action/target/@project='Apache' and action/@type='submit' and state/@name='review' ) or (action/target/@project='Apache' and action/@type='maintenance_release' and state/@name='review' )"
    assert_response :success

    assert_xml_tag tag: "collection", attributes: { "matches"=> "1" }
    assert_xml_tag tag: "request", children: { count: 3, only: { tag: "review"} }
    assert_xml_tag tag: "request", children: { count: 3, only: { tag: "history"} }

    get "/search/request", :match => "[@id=#{997}]"
    assert_response :success

  end

  def get_package_count
    return ActiveXML::Node.new(@response.body).each_package.length
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

  def test_find_owner
    prepare_request_with_user "king", "sunflower"

    get "/search/owner"
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => "no_binary" }

    # must be after first search controller call or backend might not be started on single test case runs
    wait_for_publisher()

    get "/search/owner?binary='package'"
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { :code => "attribute_not_set" }

    get "/search/owner?binary='package'&attribute='OBS:does_not_exist'"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => "unknown_attribute_type" }

    post "/source/home:Iggy/_attribute", "<attributes><attribute namespace='OBS' name='OwnerRootProject' /></attributes>"
    assert_response :success

    get "/search/owner?binary=DOES_NOT_EXIST"
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { :count => 0 }

    get "/search/owner?binary=package"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "fred", :role => "maintainer" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "maintainer" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "bugowner" }

    get "/search/owner?binary=package&filter=bugowner"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :rootproject => "home:Iggy", :project => "home:Iggy", :package => "TestPack" }
    assert_no_xml_tag :tag => 'person', :attributes => { :name => "fred", :role => "maintainer" }
    assert_no_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "maintainer" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "bugowner" }

    # set devel package (this one has another devel package in home:coolo:test)
    pkg = Package.find_by_project_and_name "home:Iggy", "TestPack"
    pkg.develpackage = Package.find_by_project_and_name "kde4", "kdelibs"
    pkg.save

    # include devel package
    get "/search/owner?binary=package"
    assert_response :success
#    assert_no_xml_tag :tag => 'owner', :attributes => { :package => nil }
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "tom", :role => "maintainer" }

    # search again, but ignore devel package
    get "/search/owner?binary=package&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "fred", :role => "maintainer" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "maintainer" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "bugowner" }

    # find all instances
    get "/search/owner?binary=package&limit=-1&expand=1&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }

    # search via project link
    put "/source/TEMPORARY/_meta", "<project name='TEMPORARY'><title/><description/><link project='home:Iggy'/>
                                      <group groupid='test_group' role='maintainer' />
                                      <repository name='standard'>
                                        <path project='home:Iggy' repository='10.2'/>
                                        <arch>i586</arch>
                                      </repository>
                                    </project>"
    assert_response :success

    get "/search/owner?project=TEMPORARY&binary=package&limit=-1&expand=1"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy" }

    get "/search/owner?project=TEMPORARY&binary=package&limit=-1&expand=1&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }

    # additional package
    put "/source/TEMPORARY/pack/_meta", "<package name='pack' project='TEMPORARY'><title/><description/><group groupid='test_group' role='bugowner'/></package>"
    assert_response :success
    raw_put '/source/TEMPORARY/pack/package.spec', File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read()
    assert_response :success
    run_scheduler("i586")
    inject_build_job( "TEMPORARY", "pack", "standard", "i586" )
    run_scheduler("i586")
    wait_for_publisher()

    get "/search/owner?project=TEMPORARY&binary=package&limit=-1&devel=false"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_xml_tag :tag => 'group', :attributes => { :name => "test_group", :role => "bugowner" }

    get "/search/owner?project=TEMPORARY&binary=package&devel=false"
    assert_response :success
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_xml_tag :tag => 'group', :attributes => { :name => "test_group", :role => "bugowner" }

    get "/search/owner?project=TEMPORARY&binary=package"
    assert_response :success
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_xml_tag :tag => 'group', :attributes => { :name => "test_group", :role => "bugowner" }

    get "/search/owner?project=TEMPORARY&binary=package&deepest=1"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }

    # test fall through when higher project has the package, but no bugowner
    put "/source/TEMPORARY/pack/_meta", "<package name='pack' project='TEMPORARY'><title/><description/></package>"
    assert_response :success
    get "/search/owner?project=TEMPORARY&binary=package&filter=bugowner"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "home:Iggy", :package => "TestPack" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "Iggy", :role => "bugowner" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY", :package => "pack" }
    assert_no_xml_tag :tag => 'owner', :attributes => { :project => "home:coolo:test" }
    assert_no_xml_tag :tag => 'group', :attributes => { :name => "test_group", :role => "bugowner" }

    # group in project meta
    get "/search/owner?project=TEMPORARY&binary=package&filter=maintainer"
    assert_response :success
    assert_xml_tag :tag => 'owner', :attributes => { :project => "TEMPORARY" }
    assert_xml_tag :tag => 'person', :attributes => { :name => "king", :role => "maintainer" }
    assert_xml_tag :tag => 'group', :attributes => { :name => "test_group", :role => "maintainer" }

    # reset devel package setting again
    pkg.develpackage = nil
    pkg.save
    # cleanup
    delete "/source/TEMPORARY"
    assert_response :success
    delete "/source/home:Iggy/_attribute/OBS:OwnerRootProject"
    assert_response :success
  end

  def test_find_owner_when_binary_exist_in_Update_but_definition_is_in_GA_project
    prepare_request_with_user "king", "sunflower"

    # must be after first search controller call or backend might not be started on single test case runs
    wait_for_publisher()

    # setup projects and packages
    put "/source/TEMPORARY:GA/_meta", "<project name='TEMPORARY:GA'><title/><description/>
                                      <repository name='standard'>
                                        <path project='home:Iggy' repository='10.2'/>
                                        <arch>i586</arch>
                                      </repository>
                                    </project>"
    assert_response :success
    put "/source/TEMPORARY:Update/_meta", "<project name='TEMPORARY:Update'><title/><description/><link project='TEMPORARY:GA'/>
                                      <repository name='standard'>
                                        <path project='home:Iggy' repository='10.2'/>
                                        <arch>i586</arch>
                                      </repository>
                                    </project>"
    assert_response :success
    put "/source/TEMPORARY:Update/package/_meta", "<package name='package' project='TEMPORARY:Update'><title/><description/> </package>"
    assert_response :success
    put "/source/TEMPORARY:GA/package/_meta", "<package name='package' project='TEMPORARY:GA'><title/><description/>
                                                 <person userid='fred' role='bugowner' />
                                               </package>"
    assert_response :success
    raw_put '/source/TEMPORARY:GA/package/package.spec', File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read()
    assert_response :success
    raw_put '/source/TEMPORARY:Update/package/package.spec', File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read()
    assert_response :success

    # package exists only in Update
    run_scheduler("i586")
    inject_build_job( "TEMPORARY:Update", "package", "standard", "i586" )
    run_scheduler("i586")
    wait_for_publisher()

    # search: upper hit
    get "/search/owner?binary=package&project=TEMPORARY:Update"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => "TEMPORARY:Update", :project => "TEMPORARY:Update" } },
                   :tag => "person", :attributes => { :name => "king", :role => "maintainer" }
    # search: find definition in package below without this binary
    get "/search/owner?binary=package&project=TEMPORARY:Update&filter=bugowner"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'owner', :attributes => { :rootproject => "TEMPORARY:Update", :project => "TEMPORARY:GA", :package => "package" } },
                   :tag => "person", :attributes => { :name => "fred", :role => "bugowner" }

    # cleanup
    delete "/source/TEMPORARY:Update"
    assert_response :success
    delete "/source/TEMPORARY:GA"
    assert_response :success
  end
end

