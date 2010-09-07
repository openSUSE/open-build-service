require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class SourceControllerTest < ActionController::IntegrationTest 
  fixtures :all
  
  def test_get_projectlist
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :only => { :tag => "entry" } }
  end

  def test_get_projectlist_with_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success 
    assert_no_match /entry name="HiddenProject"/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match /entry name="HiddenProject"/, @response.body
  end

  def test_get_projectlist_with_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success 
    assert_match /entry name="SourceprotectedProject"/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match /entry name="SourceprotectedProject"/, @response.body
  end


  def test_get_projectlist_with_viewprotected_project
    # visible, but no sources
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success 
    assert_match /entry name="ViewprotectedProject"/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match /entry name="ViewprotectedProject"/, @response.body
  end

  def test_get_packagelist
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2, :only => { :tag => "entry" } }
  end

  def test_resubmit_fixtures
    # this just reads and writes again the data from the fixtures
    prepare_request_with_user "king", "sunflower"

    # projects
    get "/source"
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    node.each_entry do |e|
      get "/source/#{e.name}/_meta"
      assert_response :success
      r = @response.body
      # FIXME: add some more validation checks here
      put "/source/#{e.name}/_meta", r
      assert_response :success
      get "/source/#{e.name}/_meta"
      assert_response :success
      assert_not_nil r
      assert_equal r, @response.body

      # packages
      get "/source/#{e.name}"
      assert_response :success
      packages = ActiveXML::XMLNode.new(@response.body)
      packages.each_entry do |p|
        get "/source/#{e.name}/#{p.name}/_meta"
        assert_response :success
        r = @response.body
        # FIXME: add some more validation checks here
        put "/source/#{e.name}/#{p.name}/_meta", r
        assert_response :success
        get "/source/#{e.name}/#{p.name}/_meta"
        assert_response :success
        assert_not_nil r
        assert_equal r, @response.body
      end
    end
    
  end

  def test_get_packagelist_with_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject"
    assert_response 404
    assert_match /unknown_project/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject"
    assert_response :success 
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2, :only => { :tag => "entry" } }
    assert_match /entry name="pack"/, @response.body
    assert_match /entry name="pack1"/, @response.body
  end

  def test_get_packagelist_with_sourceprotected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject"
    assert_response :success 
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry" } }
    assert_match /entry name="pack"/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/SourceprotectedProject"
    assert_response :success 
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry" } }
    assert_match /entry name="pack"/, @response.body
  end

  # non-existing project should return 404
  def test_get_illegal_project
    prepare_request_with_user "tom", "thunder"
    get "/source/kde2000/_meta"
    assert_response 404
  end


  # non-existing project-package should return 404
  def test_get_illegal_projectfile
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs2000/_meta"
    assert_response 404
  end


  def test_get_project_meta
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "kde4" }
  end

  def test_get_project_meta_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/_meta"
    assert_response 404
    assert_match /unknown_project/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "HiddenProject" }
  end

  def test_get_project_meta_from_viewprotected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/ViewprotectedProject/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "ViewprotectedProject" }
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "view_homer", "homer"
    get "/source/ViewprotectedProject/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "ViewprotectedProject" }
  end

  def test_get_project_meta_from_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "SourceprotectedProject" }
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "SourceprotectedProject" }
  end

  def test_get_package_filelist
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "my_patch.diff" } } }
 
    # now testing if also others can see it
    prepare_request_with_user "Iggy", "asdfasdf"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "my_patch.diff" } } }

  end

  def test_get_package_filelist_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack"
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "unknown_package" }
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/pack"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2 }
  end

  def test_get_package_filelist_from_viewprotected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/ViewprotectedProject/pack"
    assert_response :success
    assert_tag :tag => "status", :attributes => { :code => "ok" }
    assert_match /<details><\/details>/, @response.body
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/ViewprotectedProject/pack"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "my_file" } } }
  end

  def test_get_package_filelist_from_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack"
    assert_response :success
    # filelist visible, but files itself not
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2 }
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack"
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 2 }
  end

  def test_get_package_meta
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "kdelibs" }
  end

  def test_get_package_meta_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack/_meta"
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "unknown_package" }
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/pack/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack" , :project => "HiddenProject"}
  end

  def test_get_package_meta_from_viewprotected_project
    # not listing files, but package meta is visible
    prepare_request_with_user "tom", "thunder"
    get "/source/ViewprotectedProject/pack/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack" , :project => "ViewprotectedProject"}
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/ViewprotectedProject/pack/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack" , :project => "ViewprotectedProject"}
  end

  def test_get_package_meta_from_sourceacces_protected_project
    # package meta is visible
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack" , :project => "SourceprotectedProject"}
    # retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack" , :project => "SourceprotectedProject"}
  end

  # project_meta does not require auth
  def test_invalid_user
    prepare_request_with_user "king123", "sunflower"
    get "/source/kde4/_meta"
    assert_response 401
  end
  
  def test_valid_user
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/_meta"
    assert_response :success
  end

  
  def test_put_project_meta_with_invalid_permissions
    prepare_request_with_user "tom", "thunder"
    # The user is valid, but has weak permissions
    
    # Get meta file
    get "/source/kde4/_meta"
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4"), doc.to_s
    assert_response 403

    # admin only tag    
    d = doc.elements["/project"]
    d = d.add_element "remoteurl"
    d.text = "http://localhost:5352"
    prepare_request_with_user "fred", "geröllheimer"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4"), doc.to_s
    assert_response 403
    assert_match(/admin rights are required to change remoteurl/, @response.body)

    # invalid xml
    put url_for(:controller => :source, :action => :project_meta, :project => "NewProject"), "<asd/>"
    assert_response 400
    assert_match(/validation failed/, @response.body)

    # new project
    put url_for(:controller => :source, :action => :project_meta, :project => "NewProject"), "<project name='NewProject'><title>blub</title><description/></project>"
    assert_response 403
    assert_match(/not allowed to create new project/, @response.body)

    prepare_request_with_user "king", "sunflower"
    put url_for(:controller => :source, :action => :project_meta, :project => "_NewProject"), "<project name='_NewProject'><title>blub</title><description/></project>"
    assert_response 400
    assert_match(/projid '_NewProject' is illegal/, @response.body)
  end


  def test_put_project_meta
    prj="kde4"      # project
    resp1=:success  # expected response 1 & 2
    resp2=:success  # \/ expected assert
    aresp={:tag => "status", :attributes => { :code => "ok" } }
    match=true      # value written matches 2nd read
    # admin
    prepare_request_with_user "king", "sunflower"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer 
    prepare_request_with_user "fred", "geröllheimer"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer via group
    prepare_request_with_user "adrian", "so_alone"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
  end


  def test_put_project_meta_hidden_project
    prj="HiddenProject"
    # uninvolved user
    resp1=404 
    resp2=nil
    aresp=nil
    match=nil
    prepare_request_with_user "tom", "thunder"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok" } }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # FIXME: maintainer via group
  end

  def test_put_project_meta_viewprotected_project
    prj="ViewprotectedProject"
    # uninvolved user
    resp1=:success
    resp2=403
    aresp={:tag => "status", :attributes => { :code => "change_project_no_permission" } }
    match=nil
    prepare_request_with_user "tom", "thunder"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok" } }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
  end

  def test_put_project_meta_sourceaccess_protected_project
    prj="SourceprotectedProject"
    # uninvolved user - can't change meta
    resp1=:success
    resp2=403
    aresp={:tag => "status", :attributes => { :code => "change_project_no_permission" } }
    match=nil
    prepare_request_with_user "tom", "thunder"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok" } }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
  end

  def do_change_project_meta_test (project, response1, response2, tag2, doesmatch)
   # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => project)
    assert_response response1
    if not ( response2 and tag2 )
      #dummy write to check blocking
      put url_for(:action => :project_meta, :project => project), "<project name=\"#{project}\"><title></title><description></description></project>"
      assert_response 404
      assert_match /unknown_project/, @response.body
      return
    end

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:action => :project_meta, :project => project), doc.to_s
    assert_response response2
    assert_tag(tag2)

    # Get data again and check that it is the changed data
    get url_for(:action => :project_meta, :project => project)
    doc = REXML::Document.new( @response.body )
    d = doc.elements["//description"]
    assert_equal new_desc, d.text if doesmatch
  end
  private :do_change_project_meta_test


  def test_create_project_meta
    do_create_project_meta_test("king", "sunflower")
  end
  
  
  def do_create_project_meta_test (name, pw)
    prepare_request_with_user( name, pw)
    # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    xml = @response.body
    doc = REXML::Document.new( xml )
    # change name to kde5: 
    d = doc.elements["/project"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kde5' ) 
    put url_for(:controller => :source, :action => :project_meta, :project => "kde5"), doc.to_s
    assert_response(:success, message="--> #{name} was not allowed to create a project")
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :project_meta, :project => "kde5")
    assert_response :success
    assert_select "project[name=kde5]"
    assert_select "person[userid=king][role=maintainer]", {}, "Creator was not added as project maintainer"
  end
  private :do_create_project_meta_test
  
  
  
  
  def test_put_invalid_project_meta
    prepare_request_with_user "fred", "geröllheimer"

   # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4"), doc.to_s + "</xml>"
    assert_response 400

    prepare_request_with_user "king", "sunflower"
    # write to illegal location: 
    put url_for(:controller => :source, :action => :project_meta, :project => "../source/bang"), doc.to_s
    assert_response( 404, "--> Was able to create project at illegal path")
    put url_for(:controller => :source, :action => :project_meta)
    assert_response( 400, "--> Was able to create project at illegal path")
    put url_for(:controller => :source, :action => :project_meta, :project => ".")
    assert_response( 400, "--> Was able to create project at illegal path")
    
    #must not create a project with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :project_meta, :project => "kde5"), doc.to_s
    assert_response( 400, "--> Was able to create project with different project-name in _meta.xml")    
    
    #TODO: referenced repository names must exist
    
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4" )
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end
  
  
  
  def test_put_package_meta_with_invalid_permissions
    prepare_request_with_user "tom", "thunder"
    # The user is valid, but has weak permissions
    
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s
    assert_response 403
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new(( @response.body )).to_s)    
  end

  def test_put_package_meta_to_hidden_pkg_invalid_permissions
    prepare_request_with_user "tom", "thunder"
    # The user is valid, but has weak permissions
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "pack")
    assert_response 404

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "pack"), "<package name=\"foo\"><title></title><description></description></package>"
    assert_response 404
  end

  def do_change_package_meta_test (project, package, response1, response2, tag2, match)
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response1

    if not ( response2 and tag2 )
      #dummy write to check blocking
      put url_for(:controller => :source, :action => :package_meta, :project => project, package => package), "<package name=\"#{package}\"><title></title><description></description></package>"
      assert_response 404
      assert_match /unknown_package/, @response.body
      return
    end
    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => project, :package => package), doc.to_s
    assert_response response2 #(:success, "--> Was not able to update kdelibs _meta")   
    assert_tag tag2 #( :tag => "status", :attributes => { :code => "ok"} )

    # Get data again and check that it is the changed data
    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["//description"]
    #ignore updated change
    newdoc.root.attributes['updated'] = doc.root.attributes['updated']
    assert_equal new_desc, d.text if match
    assert_equal doc.to_s, newdoc.to_s if match
  end
  private :do_change_package_meta_test


  # admins, project-maintainer and package maintainer can edit package data
  def test_put_package_meta
    prj="kde4"
    pkg="kdelibs"
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok"} }
    match=true
    # admin
    prepare_request_with_user "king", "sunflower"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # maintainer via user
    prepare_request_with_user "fred", "geröllheimer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    prepare_request_with_user "fredlibs", "geröllheimer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # maintainer via group
    prepare_request_with_user "adrian", "so_alone"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
  end

  def test_put_package_meta_hidden_package
    prj="HiddenProject"
    pkg="pack"
    resp1=404
    resp2=nil
    aresp=nil
    match=false
    # uninvolved user
    prepare_request_with_user "fred", "geröllheimer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok"} }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
  end

  def test_put_package_meta_viewprotected_package
    prj="ViewprotectedProject"
    pkg="pack"
    resp1=:success
    resp2=403
    aresp={:tag => "status", :attributes => { :code => "change_package_no_permission" } }
    match=nil
    # uninvolved user
    prepare_request_with_user "fred", "geröllheimer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok"} }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
  end

  def test_put_package_meta_sourceaccess_protected_package
    prj="SourceprotectedProject"
    pkg="pack"
    resp1=:success
    resp2=403
    aresp={:tag => "status", :attributes => { :code => "change_package_no_permission" } }
    match=nil
    # uninvolved user
    prepare_request_with_user "fred", "geröllheimer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # admin
    resp1=:success
    resp2=:success
    aresp={:tag => "status", :attributes => { :code => "ok"} }
    match=true
    prepare_request_with_user "king", "sunflower"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    do_change_package_meta_test(prj,pkg,resp1,resp2,aresp,match)
  end

  def test_create_package_meta
    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    #change name to kdelibs2
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kdelibs2' ) 
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2"), doc.to_s
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )
    
    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2")
    assert_response :success
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["/package"]
    assert_equal(d.attribute('name').value(), 'kdelibs2', message="Project name was not set to kdelibs2")
  end

  def do_test_change_package_meta (project, package, response1, response2, tag2, response3, select3)
    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response1
    if not (response2 or tag2 or response3 or select3)
      #dummy write to check blocking
      put url_for(:controller => :source, :action => :package_meta, :project => project, package => package), "<package name=\"#{package}\"><title></title><description></description></package>"
      assert_response 404
      assert_match /unknown_package/, @response.body
      return
    end
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    b = d.add_element 'build'
    b.add_element 'enable'
    put url_for(:controller => :source, :action => :package_meta, :project => project, :package => package), doc.to_s
    assert_response response2
    assert_tag(tag2)

    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response3
    assert_select select3 if select3
  end

  def test_change_package_meta
    prj="kde4"      # project
    pkg="kdelibs"   # package
    resp1=:success  # assert response #1
    resp2=:success  # assert response #2
    atag2={ :tag => "status", :attributes => { :code => "ok"} } # assert_tag after response #2
    resp3=:success  # assert respons #3
    asel3="package > build > enable" # assert_select after response #3
    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)
  end

  def test_change_package_meta_hidden
    prj="HiddenProject"
    pkg="pack"
    # uninvolved user
    resp1=404
    resp2=nil
    atag2=nil
    resp3=nil
    asel3=nil
    prepare_request_with_user "fred", "geröllheimer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)
    resp1=:success
    resp2=:success
    atag2={ :tag => "status", :attributes => { :code => "ok"} }
    resp3=:success
    asel3="package > build > enable"
    # maintainer
    prepare_request_with_user "adrian", "so_alone"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)
  end

  def test_change_package_meta_viewprotect
    prj="ViewprotectedProject"
    pkg="pack"
    # uninvolved user
    resp1=:success
    resp2=403
    atag2={ :tag => "status", :attributes => { :code => "change_package_no_permission"} }
    resp3=:success
    asel3=nil
    prepare_request_with_user "fred", "geröllheimer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)

    # maintainer
    resp1=:success
    resp2=:success
    atag2={ :tag => "status", :attributes => { :code => "ok"} }
    resp3=:success
    asel3="package > build > enable"
    prepare_request_with_user "view_homer", "homer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)
  end

  def test_change_package_meta_sourceaccess_protect
    prj="SourceprotectedProject"
    pkg="pack"
    # uninvolved user
    resp1=:success
    resp2=403
    atag2={ :tag => "status", :attributes => { :code => "change_package_no_permission"} }
    resp3=:success
    asel3=nil
    prepare_request_with_user "fred", "geröllheimer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)

    # maintainer
    resp1=:success
    resp2=:success
    atag2={ :tag => "status", :attributes => { :code => "ok"} }
    resp3=:success
    asel3="package > build > enable"
    prepare_request_with_user "sourceaccess_homer", "homer"
    do_test_change_package_meta(prj,pkg,resp1,resp2,atag2,resp3,asel3)
  end

  def test_put_invalid_package_meta
    prepare_request_with_user "fredlibs", "geröllheimer"
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s + "</xml>"
    assert_response 400

    prepare_request_with_user "king", "sunflower"
    # write to illegal location: 
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "../bang"), doc.to_s
    assert_response( 404, "--> Was able to create package at illegal path")
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4"), doc.to_s
    assert_response( 404, "--> Was able to create package at illegal path")
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "."), doc.to_s
    assert_response( 400, "--> Was able to create package at illegal path")
    
    #must not create a package with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2000"), doc.to_s
    assert_response( 400, "--> Was able to create package with different project-name in _meta.xml")     

    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end



  def test_read_file
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs/my_patch.diff"
    assert_response :success
    assert_equal( @response.body.to_s, "argl" )
    
    get "/source/kde4/kdelibs/BLUB"
    #STDERR.puts(@response.body)
    assert_response 404
    assert_tag( :tag => "status" )
    
    get "/source/kde4/kdelibs/../kdebase/_meta"
    #STDERR.puts(@response.body)
    assert_response( 404, "Was able to read file outside of package scope" )
    assert_tag( :tag => "status" )
  end

  def test_read_file_hidden_proj
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/HiddenProject/pack/my_file"
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "not_found"} 
    # uninvolved, 
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack/my_file"
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "not_found"} 
    # reader
    # downloader
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    get "/source/HiddenProject/pack/my_file"
    assert_response :success
    assert_equal( @response.body.to_s, "Protected Content")
    # admin
    prepare_request_with_user "king", "sunflower"
    get "/source/HiddenProject/pack/my_file"
    assert_response :success
    assert_equal( @response.body.to_s, "Protected Content")
  end

  def test_read_file_sourceaccess_proj
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
    # uninvolved, 
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
    # reader
    # downloader
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response :success
    assert_equal( @response.body.to_s, "Protected Content")
    # admin
    prepare_request_with_user "king", "sunflower"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response :success
    assert_equal( @response.body.to_s, "Protected Content")
  end

  def add_file_to_package (url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    get url1
    # before md5
    assert_tag asserttag1 if asserttag1
    teststring = '&;'
    put url2, teststring
    assert_response assertresp2
    # afterwards new md5
    assert_select assertselect2, assertselect2rev if assertselect2
    # reread file
    get url2
    assert_response assertresp3 
    assert_equal teststring, @response.body if asserteq3
    # delete
    delete url2
    assert_response assertresp4
    # file gone
    get url2
    assert_response 404 if asserteq3
  end
  private :add_file_to_package

  def test_add_file_to_package_hidden
    # uninvolved user
    prepare_request_with_user "fredlibs", "geröllheimer"
    url1="/source/HiddenProject/pack"
    asserttag1={ :tag => 'status', :attributes => { :code => "unknown_package"} }
    url2="/source/HiddenProject/pack/testfile"
    assertresp2=404
    assertselect2=nil
    assertselect2rev=nil
    assertresp3=404
    asserteq3=nil
    assertresp4=404
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    asserttag1={:tag => 'directory', :attributes => { :srcmd5 => "47a5fb1c73c75bb252283e2ad1110182" }}
    assertresp2=:success
    assertselect2="revision > srcmd5"
    assertselect2rev='16bbde7f26e318a5c893c182f7a3d433'
    assertresp3=:success
    asserteq3=true
    assertresp4=:success
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # admin
    prepare_request_with_user "king", "sunflower"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
  end

  def test_add_file_to_package_viewprotect
    # uninvolved user
    prepare_request_with_user "fredlibs", "geröllheimer"
    url1="/source/ViewprotectedProject/pack"
    asserttag1={ :tag => 'status', :attributes => { :code => "ok"} }
    url2="/source/ViewprotectedProject/pack/testfile"
    assertresp2=403
    assertselect2=nil
    assertselect2rev=nil
    assertresp3=404
    asserteq3=nil
    assertresp4=403
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    asserttag1={:tag => 'directory', :attributes => { :srcmd5 => "20189c0a1f15a9628e7d0ae59edd0c49" }}
    assertresp2=:success
    assertselect2="revision > srcmd5"
    assertselect2rev='38ba097d164af7973f8508a3e73db3da'
    assertresp3=:success
    asserteq3=true
    assertresp4=:success
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # admin
    prepare_request_with_user "king", "sunflower"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
  end

  def test_add_file_to_package_sourceaccess_protect
    # uninvolved user
    prepare_request_with_user "fredlibs", "geröllheimer"
    url1="/source/SourceprotectedProject/pack"
    asserttag1={ :tag => 'directory', :attributes => { :srcmd5 => "47a5fb1c73c75bb252283e2ad1110182"} }
    url2="/source/SourceprotectedProject/pack/testfile"
    assertresp2=403
    assertselect2=nil
    assertselect2rev=nil
    assertresp3=403
    asserteq3=nil
    assertresp4=403
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    asserttag1={:tag => 'directory', :attributes => { :srcmd5 => "47a5fb1c73c75bb252283e2ad1110182" }}
    assertresp2=:success
    assertselect2="revision > srcmd5"
    assertselect2rev='16bbde7f26e318a5c893c182f7a3d433'
    assertresp3=:success
    asserteq3=true
    assertresp4=:success
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # admin
    prepare_request_with_user "king", "sunflower"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
  end

  def test_add_file_to_package
    url1="/source/kde4/kdelibs"
    asserttag1={ :tag => 'directory', :attributes => { :srcmd5 => "1636661d96a88cd985d82dc611ebd723" } }
    url2="/source/kde4/kdelibs/testfile"
    assertresp2=:success
    assertselect2="revision > srcmd5"
    assertselect2rev='bc1d31b2403fa8925b257101b96196ec'
    assertresp3=:success
    asserteq3=true
    assertresp4=:success
    prepare_request_with_user "fredlibs", "geröllheimer"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    prepare_request_with_user "fred", "geröllheimer"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    prepare_request_with_user "king", "sunflower"
    add_file_to_package(url1, asserttag1, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # write without permission: 
    prepare_request_with_user "tom", "thunder"
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff")
    assert_response :success
    origstring = @response.body.to_s
    teststring = "&;"
    put url_for(:action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff"), teststring
    assert_response( 403, message="Was able to write a package file without permission" )
    assert_tag( :tag => "status" )
    
    # check that content is unchanged: 
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff")
    assert_response :success
    assert_equal( @response.body.to_s, origstring, message="Package file was changed without permissions" )

    # invalid permission
    ActionController::IntegrationTest::reset_auth 
    delete "/source/kde4/kdelibs/my_patch.diff"
    assert_response 401

    prepare_request_with_user "adrian_nobody", "so_alone"
    delete "/source/kde4/kdelibs/my_patch.diff"
    assert_response 403
  
    get "/source/kde4/kdelibs/my_patch.diff"
    assert_response :success
  end
  
  def test_remove_and_undelete_operations
    ActionController::IntegrationTest::reset_auth 
    delete "/source/kde4/kdelibs"
    assert_response 401
    delete "/source/kde4"
    assert_response 401

    # delete single package in project
    prepare_request_with_user "fredlibs", "geröllheimer"
    delete "/source/kde4/kdelibs" 
    assert_response :success

    get "/source/kde4/kdelibs" 
    assert_response 404
    get "/source/kde4/kdelibs/_meta" 
    assert_response 404

    # list deleted packages
    get "/source/kde4", :deleted => 1
    assert_response 200
    assert_tag( :tag => "entry", :attributes => { :name => "kdelibs"} )

    # undelete single package
    post "/source/kde4/kdelibs", :cmd => :undelete
    assert_response :success
    get "/source/kde4/kdelibs"
    assert_response :success
    get "/source/kde4/kdelibs/_meta"
    assert_response :success

    # delete entire project
    delete "/source/kde4" 
    assert_response :success

    get "/source/kde4" 
    assert_response 404
    get "/source/kde4/_meta" 
    assert_response 404

    # list content of deleted project
    prepare_request_with_user "king", "sunflower"
    get "/source", :deleted => 1
    assert_response 200
    assert_tag( :tag => "entry", :attributes => { :name => "kde4"} )
    prepare_request_with_user "fredlibs", "geröllheimer"
    get "/source", :deleted => 1
    assert_response 403
    assert_match(/only admins can see deleted projects/, @response.body)

    prepare_request_with_user "fredlibs", "geröllheimer"
    # undelete project
    post "/source/kde4", :cmd => :undelete
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    post "/source/kde4", :cmd => :undelete
    assert_response :success

    # content got restored ?
    get "/source/kde4"
    assert_response :success
    get "/source/kde4/_project"
    assert_response :success
    get "/source/kde4/_meta"
    assert_response :success
    get "/source/kde4/kdelibs"
    assert_response :success
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    get "/source/kde4/kdelibs/my_patch.diff"
    assert_response :success

    # undelete project again
    post "/source/kde4", :cmd => :undelete
    assert_response 403
  end

  def test_remove_project_and_verify_repositories
    prepare_request_with_user "tom", "thunder" 
    delete "/source/home:coolo"
    assert_response 403
    assert_select "status[code] > summary", /Unable to delete project home:coolo; following repositories depend on this project:/

    delete "/source/home:coolo", :force => 1
    assert_response :success

    # verify the repo is updated
    get "/source/home:coolo:test/_meta"
    node = ActiveXML::XMLNode.new(@response.body)
    assert_equal node.repository.name, "home_coolo"
    assert_equal node.repository.path.project, "deleted"
    assert_equal node.repository.path.repository, "gone"
  end

  def test_diff_package
    prepare_request_with_user "tom", "thunder" 
    post "/source/home:Iggy/TestPack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
  end

  def test_diff_package_hidden_project
    prepare_request_with_user "tom", "thunder"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response 404
    assert_tag :tag => 'status', :attributes => { :code => "unknown_package"}
    #reverse
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response 404
    assert_tag :tag => 'status', :attributes => { :code => "unknown_package"}

    prepare_request_with_user "hidden_homer", "homer"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Minimal rpm package for testing the build controller/, @response.body
    # reverse
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body

    prepare_request_with_user "king", "sunflower"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Minimal rpm package for testing the build controller/, @response.body
    # reverse
    prepare_request_with_user "king", "sunflower"
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body
  end

  def test_diff_package_viewprotected_project
    prepare_request_with_user "tom", "thunder"
    post "/source/ViewprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_tag :tag => 'status', :attributes => { :code => "ok"}
    #reverse
    # FIXME: unclear implementation - leak
    post "/source/kde4/kdelibs?oproject=ViewprotectedProject&opackage=pack&cmd=diff"
    assert_response :success if $ENABLE_BROKEN_TEST
    assert_tag :tag => 'status', :attributes => { :code => "unknown_package"} if $ENABLE_BROKEN_TEST

    prepare_request_with_user "view_homer", "homer"
    post "/source/ViewprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Protected Content/, @response.body
    # reverse
    post "/source/kde4/kdelibs?oproject=ViewprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body

    prepare_request_with_user "king", "sunflower"
    post "/source/ViewprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Protected Content/, @response.body
    # reverse
    prepare_request_with_user "king", "sunflower"
    post "/source/kde4/kdelibs?oproject=ViewprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body
  end

  def test_diff_package_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response 403
    assert_tag :tag => 'status', :attributes => { :code => "source_access_no_permission"}
    #reverse
    # FIXME: unclear implementation - leak
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response 403
    assert_tag :tag => 'status', :attributes => { :code => "source_access_no_permission"}

    prepare_request_with_user "sourceaccess_homer", "homer"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Protected Content/, @response.body
    # reverse
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body

    prepare_request_with_user "king", "sunflower"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match /Protected Content/, @response.body
    # reverse
    prepare_request_with_user "king", "sunflower"
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match /argl/, @response.body
  end


  def test_pattern
    ActionController::IntegrationTest::reset_auth 
    put url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "kde4"), load_backend_file("pattern/digiKam.xml")
    assert_response 401

    prepare_request_with_user "adrian_nobody", "so_alone"
    get url_for(:controller => :source, :action => :index_pattern, :project => "DoesNotExist")
    assert_response 404
    get url_for(:controller => :source, :action => :index_pattern, :project => "kde4")
    assert_response :success
    get url_for(:controller => :source, :action => :pattern_meta, :pattern => "DoesNotExist", :project => "DoesNotExist")
    assert_response 404
    get url_for(:controller => :source, :action => :pattern_meta, :pattern => "DoesNotExist", :project => "kde4")
    assert_response 404
    put url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "kde4"), load_backend_file("pattern/digiKam.xml")
    assert_response 403
    assert_match(/no permission to store pattern/, @response.body)

    prepare_request_with_user "tom", "thunder"
    put url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "kde4"), "broken"
    assert_response 400
    assert_match(/validation failed/, @response.body)
    put url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "home:coolo:test"), load_backend_file("pattern/digiKam.xml")
    assert_response :success
    get url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "home:coolo:test")
    assert_response :success

    # delete failure
    prepare_request_with_user "adrian_nobody", "so_alone"
    delete url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "home:coolo:test")
    assert_response 403

    # successfull delete
    prepare_request_with_user "tom", "thunder"
    delete url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "home:coolo:test")
    assert_response :success
    get url_for(:controller => :source, :action => :pattern_meta, :pattern => "mypattern", :project => "home:coolo:test")
    assert_response 404
  end

  def test_prjconf
    ActionController::IntegrationTest::reset_auth 
    get url_for(:controller => :source, :action => :project_config, :project => "DoesNotExist")
    assert_response 401
    prepare_request_with_user "adrian_nobody", "so_alone"
    get url_for(:controller => :source, :action => :project_config, :project => "DoesNotExist")
    assert_response 404
    get url_for(:controller => :source, :action => :project_config, :project => "kde4")
    assert_response :success

    prepare_request_with_user "adrian_nobody", "so_alone"
    put url_for(:controller => :source, :action => :project_config, :project => "kde4"), "Substitute: nix da"
    assert_response 403

    prepare_request_with_user "tom", "thunder"
    put url_for(:controller => :source, :action => :project_config, :project => "home:coolo:test"), "Substitute: nix da"
    assert_response :success
    get url_for(:controller => :source, :action => :project_config, :project => "home:coolo:test")
    assert_response :success
  end

  def test_pubkey
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    get url_for(:controller => :source, :action => :project_pubkey, :project => "DoesNotExist")
    assert_response 404
    get url_for(:controller => :source, :action => :project_pubkey, :project => "kde4")
    assert_response 404
    assert_match(/kde4: no pubkey available/, @response.body)
    get url_for(:controller => :source, :action => :project_pubkey, :project => "BaseDistro")
    assert_response :success

    delete url_for(:controller => :source, :action => :project_pubkey, :project => "kde4")
    assert_response 403

    # FIXME: make a successful deletion of a key
  end

  def test_linked_project_operations
    # first go with a read-only user
    prepare_request_with_user "tom", "thunder"
    # pack2 exists only via linked project
    get "/source/BaseDistro2:LinkedUpdateProject/pack2"
    assert_response :success
    delete "/source/BaseDistro2:LinkedUpdateProject/pack2"
    assert_response 404
    assert_match(/unknown package 'pack2' in project 'BaseDistro2:LinkedUpdateProject'/, @response.body)

    # test not permitted commands
    post "/build/BaseDistro2:LinkedUpdateProject", :cmd => "rebuild"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "wipe"
    assert_response 403
    assert_match(/no permission to execute command 'wipe' for not existing package/, @response.body)
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "deleteuploadrev"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "commitfilelist"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "commit"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "undelete"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "linktobranch"
    assert_response 403
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "copy", :oproject => "BaseDistro:Update", :opackage => "pack2"
    assert_response 403

    # test permitted commands
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "diff", :oproject => "RemoteInstance:BaseDistro", :opackage => "pack1"
    assert_response :success
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "branch"
    assert_response :success
# FIXME: construct a linked package object to test this
#    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "linkdiff"
#    assert_response :success

    # read-write user, binary operations must be allowed
    prepare_request_with_user "king", "sunflower"
    post "/source/BaseDistro2:LinkedUpdateProject/pack2", :cmd => "rebuild"
    assert_response :success
    post "/build/BaseDistro2:LinkedUpdateProject", :cmd => "wipe"
    assert_response :success
  end

  def test_list_of_linking_instances
    prepare_request_with_user "tom", "thunder"

    # list all linking projects
    post "/source/BaseDistro2", :cmd => "showlinked"
    assert_response :success
    assert_tag( :tag => "project", :attributes => { :name => "BaseDistro2:LinkedUpdateProject"}, :content => nil )

    # list all linking packages with a local link
    post "/source/BaseDistro/pack2", :cmd => "showlinked"
    assert_response :success
    assert_tag( :tag => "package", :attributes => { :project => "BaseDistro:Update", :name => "pack2" }, :content => nil )

    # list all linking packages, base package is a package on a remote OBS instance
# FIXME: support for this search is possible, but not yet implemented
#    post "/source/RemoteInstance:BaseDistro/pack", :cmd => "showlinked"
#    assert_response :success
#    assert_tag( :tag => "package", :attributes => { :project => "BaseDistro:Update", :name => "pack2" }, :content => nil )
  end

  def test_create_links
    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary")
    assert_response 404
    xml = @response.body
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary"), 
        '<package project="kde4" name="temporary"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/kde4/temporary/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_match /package 'notexiting' does not exist in project 'kde4'/, @response.body

    # working local link
    put url, '<link project="BaseDistro" package="pack1" />'
    assert_response :success
    # working link to package via project link
    put url, '<link project="BaseDistro2:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote package
    put url, '<link project="RemoteInstance:BaseDistro" package="pack1" />'
    assert_response :success
    put url, '<link project="RemoteInstance:BaseDistro2:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote project link
    put url, '<link project="UseRemoteInstance" package="pack1" />'
    assert_response :success

    # cleanup
    delete url
  end

  def test_create_links_hidden_project
    # user without any special roles
    prepare_request_with_user "adrian", "so_alone"
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary")
    assert_response 404
    xml = @response.body
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary"), 
        '<package project="HiddenProject" name="temporary"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/HiddenProject/temporary/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="HiddenProject" package="notexisting" />'
    assert_response 404
    assert_match /package 'notexisting' does not exist in project 'HiddenProject'/, @response.body

    # working local link from hidden package to hidden package
    put url, '<link project="HiddenProject" package="pack" />'
    assert_response :success

    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary2")
    assert_response 404
    xml = @response.body
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary2"), 
        '<package project="kde4" name="temporary2"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/kde4/temporary2/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_match /package 'notexiting' does not exist in project 'kde4'/, @response.body

    # special user cannot link unprotected to protected package
    put url, '<link project="HiddenProject" package="pack1" />'
    assert_response 403

    # check this works with remote projects also
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary4")
    assert_response 404
    xml = @response.body
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "temporary4"), 
        '<package project="HiddenProject" name="temporary4"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/HiddenProject/temporary4/_link"

    # working local link from hidden package to hidden package
    put url, '<link project="LocalProject" package="remotepackage" />'
    assert_response :success

    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary3")
    assert_response 404
    xml = @response.body
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary3"), 
        '<package project="kde4" name="temporary3"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    url = "/source/kde4/temporary3/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_match /The given project notexisting does not exist/, @response.body
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_match /package 'notexiting' does not exist in project 'kde4'/, @response.body

    # normal user cannot access hidden project
    put url, '<link project="HiddenProject" package="pack1" />'
    assert_response 404

    # cleanup
    delete url
  end

  def do_branch_package_test (sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    post "/source/#{sprj}/#{spkg}", :cmd => :branch, :target_project => "#{tprj}"
    print @response.body if debug
    assert_response resp if resp
    assert_match match, @response.body if match
    get "/source/#{tprj}" if debug
    print @response.body if debug
    get "/source/#{tprj}/#{spkg}/_meta"
    print @response.body if debug
    # FIXME: implementation is not done, change to assert_tag or assert_select
    assert_match testflag, @response.body if testflag
    delete "/source/#{tprj}/#{spkg}"
    print @response.body if debug
    assert_response delresp if delresp
  end

  def test_branch_package_hidden_project_new
    # hidden -> open
    # FIXME: package doesn't inherit access from project on branch
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="HiddenProject"  # source project
    spkg="pack"           # source package
    tprj="home:tom"       # target project
    resp=401              # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=404
    match=/Unknown package pack in project HiddenProject/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    tprj="home:hidden_homer"
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/ if $ENABLE_BROKEN_TEST
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)

    # open -> hidden
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="home:coolo:test"       # source project
    spkg="kdelibs_DEVEL_package" # source package
    tprj="HiddenProject"         # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/create_package_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "hidden_homer", "homer"
    resp=:success
    delresp=:success
    match=/>HiddenProject</
    testflag=/<access>/ if $ENABLE_BROKEN_TEST
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_viewprotect_project_new
    # viewprotected -> open
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="ViewprotectedProject"  # source project
    spkg="pack"                  # source package
    tprj="home:tom"              # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=:success
    # FIXME: shouldn't we find nothing to branch instead of "Ok" ?
    resp=404 if $ENABLE_BROKEN_TEST
    match=/Ok/
    # FIXME: invisible should result in unknown
    match=/Unknown package pack in project ViewprotectedProject/ if $ENABLE_BROKEN_TEST
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    tprj="home:view_homer"
    resp=:success
    delresp=:success
    match=/>ViewprotectedProject</
    # FIXME: flag inheritance on branch
    testflag=/<privacy>/ if $ENABLE_BROKEN_TEST
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)

    # open -> viewprotected
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="home:coolo:test"       # source project
    spkg="kdelibs_DEVEL_package" # source package
    tprj="ViewprotectedProject"  # target project
    resp=401                     # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/create_package_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "view_homer", "homer"
    resp=:success
    match="ViewprotectedProject"
    testflag=nil
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_sourceaccess_protected_project_new
    # viewprotected -> open
    # unauthorized
    ActionController::IntegrationTest::reset_auth 
    sprj="SourceprotectedProject" # source project
    spkg="pack"                   # source package
    tprj="home:tom"               # target project
    resp=401                      # response
    match=/Authentication required/
    testflag=nil          # test for flag in target meta
    delresp=401           # delete again
    debug=false
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # tom/thunder
    prepare_request_with_user "tom", "thunder"
    resp=403
    match=/source_access_no_permission/
    delresp=404
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    tprj="home:sourceaccess_homer"
    resp=:success
    match="SourceprotectedProject"
    testflag=/sourceaccess/ if $ENABLE_BROKEN_TEST
    delresp=:success
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
    # admin
    prepare_request_with_user "king", "sunflower"
    do_branch_package_test(sprj, spkg, tprj, resp, match, testflag, delresp, debug)
  end

  def test_branch_package_delete_and_undelete
    ActionController::IntegrationTest::reset_auth 
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 401
    prepare_request_with_user "fredlibs", "geröllheimer"
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "NotExisting"
    assert_response 403
    assert_match(/no permission to create project/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 403
    assert_match(/no permission to create package/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :force => "1"
    assert_response 403
    assert_match(/no permission to create package/, @response.body)
 
    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"    
    assert_response :success
    get "/source/home:coolo:test/TestPack/_meta"
    assert_response :success

    # branch again
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"    
    assert_response 400
    assert_match(/branch target package already exists/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :force => "1"
    assert_response :success
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :force => "1", :rev => "1"
    assert_response :success
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :force => "1", :rev => "42424242"
    assert_response 400
    assert_match(/no such revision/, @response.body)
    # FIXME: do a real commit and branch afterwards

    # now with a new project
    post "/source/home:Iggy/TestPack", :cmd => :branch
    assert_response :success
    
    get "/source/home:tom:branches:home:Iggy/TestPack/_meta"
    assert_response :success

    get "/source/home:tom:branches:home:Iggy/_meta"
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.repository.name, "10.2"
    assert_equal ret.repository.path.repository, "10.2"
    assert_equal ret.repository.path.project, "home:Iggy"

    # check source link
    get "/source/home:tom:branches:home:Iggy/TestPack/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "home:Iggy"
    assert_equal ret.package, "TestPack"
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # Branch a package with a defined devel package
    post "/source/kde4/kdelibs", :cmd => :branch
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetproject"}, :content => "home:tom:branches:home:coolo:test" )
    assert_tag( :tag => "data", :attributes => { :name => "targetpackage"}, :content => "kdelibs_DEVEL_package" )
    assert_tag( :tag => "data", :attributes => { :name => "sourceproject"}, :content => "home:coolo:test" )
    assert_tag( :tag => "data", :attributes => { :name => "sourcepackage"}, :content => "kdelibs_DEVEL_package" )

    # delete package
    ActionController::IntegrationTest::reset_auth 
    delete "/source/home:tom:branches:home:Iggy/TestPack"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    delete "/source/home:tom:branches:home:Iggy/TestPack"
    assert_response :success

    get "/source/home:tom:branches:home:Iggy/TestPack"
    assert_response 404
    get "/source/home:tom:branches:home:Iggy/TestPack/_meta"
    assert_response 404

    # undelete package
    post "/source/home:tom:branches:home:Iggy/TestPack", :cmd => :undelete
    assert_response :success

    # content got restored ?
    get "/source/home:tom:branches:home:Iggy/TestPack"
    assert_response :success
    get "/source/home:tom:branches:home:Iggy/TestPack/_meta"
    assert_response :success
    get "/source/home:tom:branches:home:Iggy/TestPack/_link"
    assert_response :success

    # undelete package again
    post "/source/home:tom:branches:home:Iggy/TestPack", :cmd => :undelete
    assert_response 403

  end

  def test_package_set_flag
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    original = @response.body

    post "/source/home:unknown/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/project 'home:unknown' does not exist/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 400
    assert_match(/Required Parameter status missing/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=enable"
    assert_response 404
    assert_match(/Unknown package 'Nothere'/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=anything"
    assert_response 400
    assert_match(/Error: unknown status for flag 'anything'/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=set_flag&repository=10.2&arch=i586&flag=shine&status=enable"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4/kdelibs?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable"
    assert_response 403
    assert_match(/no permission to execute command/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable"
    assert_response :success # actually I consider forbidding repositories not existant

    get "/source/home:Iggy/TestPack/_meta"
    assert_not_equal original, @response.body

    get "/source/home:Iggy/TestPack/_meta?view=flagdetails"
    assert_response :success
  end


  def test_project_set_flag
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/source/home:Iggy/_meta"
    assert_response :success
    original = @response.body

    post "/source/home:unknown?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/Unknown project 'home:unknown'/, @response.body)

    post "/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 400
    assert_match(/Required Parameter status missing/, @response.body)

    post "/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=anything"
    assert_response 400
    assert_match(/Error: unknown status for flag 'anything'/, @response.body)

    post "/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=shine&status=enable"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable"
    assert_response 403
    assert_match(/no permission to execute command/, @response.body)

    post "/source/home:Iggy?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable"
    assert_response :success # actually I consider forbidding repositories not existant

    get "/source/home:Iggy/_meta"
    assert_not_equal original, @response.body

    original = @response.body
    
    post "/source/home:Iggy?cmd=set_flag&flag=build&status=enable"
    assert_response :success # actually I consider forbidding repositories not existant

    get "/source/home:Iggy/_meta"
    assert_not_equal original, @response.body

    get "/source/home:Iggy/_meta?view=flagdetails"
    assert_response :success

  end

  def test_package_remove_flag
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    original = @response.body

    post "/source/home:unknown/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/project 'home:unknown' does not exist/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586"
    assert_response 400
    assert_match(/Required Parameter flag missing/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/Unknown package 'Nothere'/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.2&arch=i586&flag=shine"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response 403
    assert_match(/no permission to execute command/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response :success

    get "/source/home:Iggy/TestPack/_meta"
    assert_not_equal original, @response.body

    # non existant repos should not change anything
    original = @response.body

    post "/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.7&arch=x86_64&flag=debuginfo"
    assert_response :success # actually I consider forbidding repositories not existant

    get "/source/home:Iggy/TestPack/_meta"
    assert_equal original, @response.body

    get "/source/home:Iggy/TestPack/_meta?view=flagdetails"
    assert_response :success
  end

  def test_project_remove_flag
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/source/home:Iggy/_meta"
    assert_response :success
    original = @response.body

    post "/source/home:unknown/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/project 'home:unknown' does not exist/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586"
    assert_response 400
    assert_match(/Required Parameter flag missing/, @response.body)

    post "/source/home:Iggy?cmd=remove_flag&repository=10.2&arch=i586&flag=shine"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response 403
    assert_match(/no permission to execute command/, @response.body)

    post "/source/home:Iggy?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response :success

    get "/source/home:Iggy/_meta"
    assert_not_equal original, @response.body

    # non existant repos should not change anything
    original = @response.body

    post "/source/home:Iggy?cmd=remove_flag&repository=10.7&arch=x86_64&flag=debuginfo"
    assert_response :success # actually I consider forbidding repositories not existant

    get "/source/home:Iggy/_meta"
    assert_equal original, @response.body

    get "/source/home:Iggy/_meta?view=flagdetails"
    assert_response :success
  end

  def test_wild_chars
    prepare_request_with_user "Iggy", "asdfasdf"
    get "/source/home:Iggy/TestPack"
    assert_response :success
   
    Suse::Backend.put( '/source/home:Iggy/TestPack/bnc#620675.diff', 'argl')
    assert_response :success

    get "/source/home:Iggy/TestPack"
    assert_response :success

    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "bnc#620675.diff" } } }

    get "/source/home:Iggy/TestPack/bnc#620675.diff"
    assert_response :success
  end

  # >>> ACL
  def do_read_access_project(user, pass, targetproject, response)
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user user, pass
    get "/source/#{targetproject}/_meta"
    assert_response response
    get "/source/#{targetproject}"
  end

  def do_read_access_package(user, pass, targetproject, package, response)
    assert_response response
    get "/source/#{targetproject}/pack"
    assert_response response
    get "/source/#{targetproject}/pack/_meta"
    assert_response response
    get "/source/#{targetproject}/pack/my_file"
    assert_response response
  end
  protected :do_read_access_project
  protected :do_read_access_package

  # >>> ACL#2: privacy flag. behaves like binary-only project
  def test_privacy_project_maintainer
    # maintainer has full access
    do_read_access_project("adrian", "so_alone", "ViewprotectedProject", :success)
    # we reuse the listing here, valid-user -> pack visible
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory", :children => { :count => 1 }
    assert_tag :child => { :tag => "entry", :attributes => { :name => "pack" } }
    do_read_access_package("adrian", "so_alone", "ViewprotectedProject", "pack", :success)
  end

  def test_privacy_project_invalid_user
    begin
      do_read_access_project("Iggy", "asdfasdf", "ViewprotectedProject", :success)
      # we reuse the listing here, invalid-user -> no packages visible
      assert_tag :tag => "directory", :children => { :count => 0 }
      # this should fail !
    rescue
      #
    else
      #FIXME: package in privacy-enabled project ?
      #puts "\n This test should fail! We need to verify the logic! \n"
      #do_read_access_package("Iggy", "asdfasdf", "ViewprotectedProject", "pack", 404)
    end
  end
  # TODO
  # * fetch binaries
  # ** maintainer +
  # ** other user +
  # * search 
  # <<< ACL#2: privacy flag. behaves like binary-only project

end
