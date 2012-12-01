# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class SourceControllerTest < ActionController::IntegrationTest 
  fixtures :all
  
  def test_get_projectlist
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :only => { :tag => "entry" } }
  end

  def test_get_projectlist_with_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success 
    assert_no_match(/entry name="HiddenProject"/, @response.body)

    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match(/entry name="HiddenProject"/, @response.body)
  end

  def test_get_projectlist_with_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source"
    assert_response :success 
    assert_match(/entry name="SourceprotectedProject"/, @response.body)
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match(/entry name="SourceprotectedProject"/, @response.body)
  end


  def test_get_packagelist
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 2, :only => { :tag => "entry" } }
  end

  def test_get_packagelist_with_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject"
    assert_response 404
    assert_match(/not_found/, @response.body)
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject"
    assert_response :success 
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 3, :only => { :tag => "entry" } }
    assert_match(/entry name="pack"/, @response.body)
    assert_match(/entry name="target"/, @response.body)
  end

  def test_get_packagelist_with_sourceprotected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject"
    assert_response :success 
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 2 }
    assert_match(/entry name="target"/, @response.body)
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/SourceprotectedProject"
    assert_response :success 
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 2, :only => { :tag => "entry" } }
    assert_match(/entry name="pack"/, @response.body)
    assert_match(/entry name="target"/, @response.body)
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

  def test_use_illegal_encoded_parameters
    prepare_request_with_user "king", "sunflower"
    raw_put "/source/kde4/kdelibs/DUMMY?comment=working%20with%20Uml%C3%A4ut", "WORKING"
    assert_response :success
    raw_put "/source/kde4/kdelibs/DUMMY?comment=illegalchar%96%96asd", "NOTWORKING"
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "invalid_text_encoding" }
  end

  def test_get_project_meta
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/_meta"
    assert_response :success
    assert_xml_tag :tag => "project", :attributes => { :name => "kde4" }
  end

  def test_get_project_meta_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/_meta"
    assert_response 404
    assert_match(/unknown_project/, @response.body)
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/_meta"
    assert_response :success
    assert_xml_tag :tag => "project", :attributes => { :name => "HiddenProject" }
  end

  def test_get_project_meta_from_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    assert_xml_tag :tag => "project", :attributes => { :name => "SourceprotectedProject" }
    #retry with maintainer
    reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/_meta"
    assert_response :success
    assert_xml_tag :tag => "project", :attributes => { :name => "SourceprotectedProject" }
  end

  def test_get_package_filelist
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "my_patch.diff" } } }
 
    # now testing if also others can see it
    prepare_request_with_user "Iggy", "asdfasdf"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "my_patch.diff" } } }

  end

  def test_get_package_filelist_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack"
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_project" }
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/pack"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 2 }
  end

  def test_get_package_filelist_from_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack"
    assert_response 403
    #retry with maintainer
    reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack"
    assert_response :success
    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 2 }
  end

  def test_get_package_meta
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_xml_tag :tag => "package", :attributes => { :name => "kdelibs" }
  end

  def test_get_package_meta_from_hidden_project
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack/_meta"
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_project" }
    #retry with maintainer
    reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source/HiddenProject/pack/_meta"
    assert_response :success
    assert_xml_tag :tag => "package", :attributes => { :name => "pack" , :project => "HiddenProject"}
  end

  def test_get_package_meta_from_sourceacces_protected_project
    # package meta is visible
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack/_meta"
    assert_response :success
    assert_xml_tag :tag => "package", :attributes => { :name => "pack" , :project => "SourceprotectedProject"}
    # retry with maintainer
    reset_auth
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack/_meta"
    assert_response :success
    assert_xml_tag :tag => "package", :attributes => { :name => "pack" , :project => "SourceprotectedProject"}
  end

  def test_invalid_project_and_package_name
    prepare_request_with_user "king", "sunflower"
    [ "_blah" ].each do |n|
      raw_put url_for(:controller => :source, :action => :project_meta, :project => n), "<project name='#{n}'> <title /> <description /> </project>"
      assert_response 400
      put "/source/kde4/#{n}/_meta", "<package project='kde4' name='#{n}'> <title /> <description /> </project>"
      assert_response 400
      post "/source/kde4/kdebase", :cmd => "branch", :target_package => n
      assert_response 400
      post "/source/kde4/#{n}", :cmd => "copy", :opackage => "kdebase", :oproject => "kde4"
      if n == ".."
        # this is failing already at routing
        assert_response 403
      else
        assert_response 400
      end
    end
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
    raw_put url_for(:controller => :source, :action => :project_meta, :project => "NewProject"), "<asd/>"
    assert_response 400
    assert_match(/validation error/, @response.body)

    # new project
    raw_put url_for(:controller => :source, :action => :project_meta, :project => "NewProject"), "<project name='NewProject'><title>blub</title><description/></project>"
    assert_response 403
    assert_match(/not allowed to create new project/, @response.body)

    prepare_request_with_user "king", "sunflower"
    raw_put url_for(:controller => :source, :action => :project_meta, :project => "_NewProject"), "<project name='_NewProject'><title>blub</title><description/></project>"
    assert_response 400
    #FIXME2.4 not correctly rescued assert_match(/projid '_NewProject' is illegal/, @response.body)
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

    # check history
    get "/source/kde4/_project/_history?meta=1"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
    assert_xml_tag( :tag => "user", :content => "adrian" )
  end

  def test_create_subproject
    subprojectmeta="<project name='kde4:subproject'><title></title><description/></project>"

    # nobody
    reset_auth 
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response 401
    prepare_request_with_user "tom", "thunder"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response 403
    # admin
    prepare_request_with_user "king", "sunflower"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response :success
    delete "/source/kde4:subproject"
    assert_response :success
    # maintainer 
    prepare_request_with_user "fred", "geröllheimer"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response :success
    delete "/source/kde4:subproject"
    assert_response :success
    # maintainer via group
    prepare_request_with_user "adrian", "so_alone"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response :success
    delete "/source/kde4:subproject"
    assert_response :success

    # create illegal project 
    prepare_request_with_user "fred", "geröllheimer"
    subprojectmeta="<project name='kde4_subproject'><title></title><description/></project>"
    put url_for(:controller => :source, :action => :project_meta, :project => "kde4:subproject"), subprojectmeta
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "project_name_mismatch" } 
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

  def test_put_project_meta_sourceaccess_protected_project
    prj="SourceprotectedProject"
    # uninvolved user - can't change meta
    resp1=:success
    resp2=403
    aresp={:tag => "status", :attributes => { :code => "change_project_no_permission" } }
    match=nil
    prepare_request_with_user "tom", "thunder"
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # same with set_flag command ?
    post "/source/SourceprotectedProject?cmd=set_flag&flag=sourceaccess&status=enable"
    assert_response 403
    assert_match(/no permission to execute command/, @response.body)
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
    if !( response2 && tag2 )
      #dummy write to check blocking
      put url_for(:controller => :source, :action => :project_meta, :project => project), "<project name=\"#{project}\"><title></title><description></description></project>"
      assert_response 403 #4
#      assert_match(/unknown_project/, @response.body)
      assert_match(/create_project_no_permission/, @response.body)
      return
    end

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :project_meta, :project => project), doc.to_s
    assert_response response2
    assert_xml_tag(tag2)

    # Get data again and check that it is the changed data
    get url_for(:controller => :source, :action => :project_meta, :project => project)
    assert_response :success
    assert_equal new_desc, Xmlhash.parse(@response.body)["description"] if doesmatch
  end
  private :do_change_project_meta_test


  def test_create_and_delete_project
    prepare_request_with_user("king", "sunflower")
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
    assert_response(:success, "--> king was not allowed to create a project")
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :project_meta, :project => "kde5")
    assert_response :success
    assert_select "project[name=kde5]"
    assert_select "person[userid=king][role=maintainer]", {}, "Creator was not added as project maintainer"

    prepare_request_with_user "maintenance_coord", "power"
    delete "/source/kde5"
    assert_response 403
    prepare_request_with_user "fred", "geröllheimer"
    delete "/source/kde5"
    assert_response :success
  end
  
  
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
    assert_xml_tag :tag => "status", :attributes => { :code => "validation_failed" }

    prepare_request_with_user "king", "sunflower"
    # write to illegal location: 
    put url_for(:controller => :source, :action => :project_meta, :project => "$hash"), doc.to_s
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "invalid_project_name" }
    
    #must not create a project with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :project_meta, :project => "kde5"), doc.to_s
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "project_name_mismatch" }
    #TODO: referenced repository names must exist
    
    
    #verify data is unchanged: 
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4" )
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end
  
  
  def test_lock_project
    prepare_request_with_user "Iggy", "asdfasdf"
    put "/source/home:Iggy/TestLinkPack/_meta", "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success
    put "/source/home:Iggy/TestLinkPack/_link", "<link package='TestPack' />"
    assert_response :success

    # lock project
    get "/source/home:Iggy/_meta"
    assert_response :success
    doc = REXML::Document.new( @response.body )
    doc.elements["/project"].add_element "lock"
    doc.elements["/project/lock"].add_element "enable"
    put "/source/home:Iggy/_meta", doc.to_s
    assert_response :success
    get "/source/home:Iggy/_meta"
    assert_response :success
    assert_xml_tag :parent => { :tag => "project" }, :tag => "lock" 
    assert_xml_tag :parent => { :tag => "lock" }, :tag => "enable" 

    # modifications are not allowed anymore
    delete "/source/home:Iggy"
    assert_response 403
    delete "/source/home:Iggy/TestLinkPack"
    assert_response 403
    doc.elements["/project/description"].text = "new text"
    put "/source/home:Iggy/_meta", doc.to_s
    assert_response 403
    put "/source/home:Iggy/TestLinkPack/_link", ""
    assert_response 403

    # check branching from a locked project
    post "/source/home:Iggy/TestLinkPack", :cmd => "branch"
    assert_response :success
    get "/source/home:Iggy:branches:home:Iggy/_meta"
    assert_response :success
    assert_no_xml_tag :tag => 'lock'

    # try to unlock without comment
    post "/source/home:Iggy", { :cmd => "unlock" }
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "no_comment" }

    # unlock does not work via meta data anymore
    doc.elements["/project/lock"].delete_element "enable"
    doc.elements["/project/lock"].add_element "disable"
    put "/source/home:Iggy/_meta", doc.to_s
    assert_response 403

    # check unlock command
    prepare_request_with_user "adrian", "so_alone"
    post "/source/home:Iggy", { :cmd => "unlock", :comment => "cleanup" }
    assert_response 403
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy", { :cmd => "unlock", :comment => "cleanup" }
    assert_response :success

    # cleanup works now again
    delete "/source/home:Iggy/TestLinkPack"
    assert_response :success
    delete "/source/home:Iggy:branches:home:Iggy"
    assert_response :success
  end
  
  def test_lock_package
    prepare_request_with_user "Iggy", "asdfasdf"
    put "/source/home:Iggy/TestLinkPack/_meta", "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success

    # lock package
    get "/source/home:Iggy/TestLinkPack/_meta"
    assert_response :success
    doc = REXML::Document.new( @response.body )
    doc.elements["/package"].add_element "lock"
    doc.elements["/package/lock"].add_element "enable"
    put "/source/home:Iggy/TestLinkPack/_meta", doc.to_s
    assert_response :success
    get "/source/home:Iggy/TestLinkPack/_meta"
    assert_response :success
    assert_xml_tag :parent => { :tag => "package" }, :tag => "lock" 
    assert_xml_tag :parent => { :tag => "lock" }, :tag => "enable" 

    # modifications are not allowed anymore
    delete "/source/home:Iggy/TestLinkPack"
    assert_response 403
    doc.elements["/package/description"].text = "new text"
    put "/source/home:Iggy/TestLinkPack/_meta", doc.to_s
    assert_response 403
    put "/source/home:Iggy/TestLinkPack/_link", ""
    assert_response 403

    # make package read-writable is not working via meta
    doc.elements["/package/lock"].delete_element "enable"
    doc.elements["/package/lock"].add_element "disable"
    put "/source/home:Iggy/TestLinkPack/_meta", doc.to_s
    assert_response 403

    # try to unlock without comment
    post "/source/home:Iggy/TestLinkPack", { :cmd => "unlock" }
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "no_comment" }
    # without permissions
    prepare_request_with_user "adrian", "so_alone"
    post "/source/home:Iggy/TestLinkPack", { :cmd => "unlock", :comment => "BlahFasel" }
    assert_response 403
    # do for real and cleanup
    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy/TestLinkPack", { :cmd => "unlock", :comment => "BlahFasel" }
    assert_response :success
    delete "/source/home:Iggy/TestLinkPack"
    assert_response :success
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

    # try to trick api via non matching xml attributes
    doc.root.attributes["project"] = "kde4"
    put url_for(:controller => :source, :action => :package_meta, :project => "home:tom", :package => "kdelibs"), doc.to_s
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "project_name_mismatch"} )
    doc.root.attributes["project"] = nil
    doc.root.attributes["name"] = "none"
    put url_for(:controller => :source, :action => :package_meta, :project => "home:tom", :package => "kdelibs"), doc.to_s
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "package_name_mismatch"} )
  end

  def test_put_package_meta_to_hidden_pkg_invalid_permissions
    prepare_request_with_user "tom", "thunder"
    # The user is valid, but has weak permissions
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "pack")
    assert_response 404

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "pack"), "<package name=\"pack\"><title></title><description></description></package>"
    assert_response 404
  end

  def do_change_package_meta_test (project, package, response1, response2, tag2, match)
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response1

    if !( response2 && tag2 )
      #dummy write to check blocking
      put url_for(:controller => :source, :action => :package_meta, :project => project, :package => package), "<package><title></title><description></description></package>"
      assert_response 404
#      assert_match(/unknown_package/, @response.body)
      assert_match(/unknown_project/, @response.body)
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
    assert_xml_tag tag2 #( :tag => "status", :attributes => { :code => "ok"} )

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

    # check history
    get "/source/kde4/kdelibs/_history?meta=1"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
    assert_xml_tag( :tag => "user", :content => "adrian" )
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
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )
    # do not allow to create it with invalid name
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs3"), doc.to_s
    assert_response 400
    
    # Get data again and check that the maintainer was added
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2")
    assert_response :success
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["/package"]
    assert_equal(d.attribute('name').value(), 'kdelibs2', "Project name was not set to kdelibs2")

    # check for lacking permission to create a package
    prepare_request_with_user "tom", "thunder"
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kdelibs3' ) 
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs3"), newdoc.to_s
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "create_package_no_permission"} )
  end

  def test_captial_letter_change
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => "path", :attributes => { :project => 'home:tom:projectA' }
    assert_no_xml_tag :tag => "path", :attributes => { :project => 'home:tom:projecta' }

    # write again with a capital letter change
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projecta' repository='repoA' /> </repository> </project>"
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => 'unknown_project' }
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => "path", :attributes => { :project => 'home:tom:projectA' }
    assert_no_xml_tag :tag => "path", :attributes => { :project => 'home:tom:projecta' }

    # change back using remote project
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='RemoteInstance:home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => "path", :attributes => { :project => 'RemoteInstance:home:tom:projectA' }
    assert_no_xml_tag :tag => "path", :attributes => { :project => 'RemoteInstance:home:tom:projecta' }

if $ENABLE_BROKEN_TEST
# FIXME: the case insensitive database select is not okay.
    # and switch letter again
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='RemoteInstance:home:tom:projecta' repository='repoA' /> </repository> </project>"
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => 'unknown_project' }
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => "path", :attributes => { :project => 'RemoteInstance:home:tom:projectA' }
    assert_no_xml_tag :tag => "path", :attributes => { :project => 'RemoteInstance:home:tom:projecta' }
end

    # cleanup
    delete "/source/home:tom:projectB"
    assert_response :success
    delete "/source/home:tom:projectA"
    assert_response :success
  end

  def test_repository_dependencies
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    put "/source/home:tom:projectC/_meta", "<project name='home:tom:projectC'> <title/> <description/> <repository name='repoC'> <path project='home:tom:projectB' repository='repoB' /> </repository> </project>"
    assert_response :success
    # delete a repo
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "repo_dependency"} )
    delete "/source/home:tom:projectA"
    assert_response 403
    put "/source/home:tom:projectA/_meta?force=1", "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :success
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => 'path', :attributes => { :project => "deleted", :repository => "deleted" }
    get "/source/home:tom:projectC/_meta"
    assert_response :success
    assert_xml_tag :tag => 'path', :attributes => { :project => "home:tom:projectB", :repository => "repoB" } # unmodified

    # cleanup
    delete "/source/home:tom:projectA"
    assert_response :success
    delete "/source/home:tom:projectB"
    assert_response 403 # projectC still linking
    delete "/source/home:tom:projectC"
    assert_response :success
    delete "/source/home:tom:projectB"
    assert_response :success
  end

  def test_full_remove_repository_dependencies
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    put "/source/home:tom:projectC/_meta", "<project name='home:tom:projectC'> <title/> <description/> <repository name='repoC'> <path project='home:tom:projectB' repository='repoB' /> </repository> </project>"
    assert_response :success
    # delete a repo
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "repo_dependency"} )
    delete "/source/home:tom:projectA"
    assert_response 403
    put "/source/home:tom:projectA/_meta?force=1&remove_linking_repositories=1", "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :success
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_no_xml_tag :tag => 'path'
    get "/source/home:tom:projectC/_meta"
    assert_response :success
    assert_no_xml_tag :tag => 'path'

    # cleanup
    delete "/source/home:tom:projectA"
    assert_response :success
    delete "/source/home:tom:projectB"
    assert_response :success
    delete "/source/home:tom:projectC"
    assert_response :success
  end

  def test_delete_project_with_repository_dependencies
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:projectA/_meta", "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'> <arch>i586</arch> </repository> </project>"
    assert_response :success
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> <arch>i586</arch> </repository> </project>"
    assert_response :success
    # delete the project including the repository
    delete "/source/home:tom:projectA"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "repo_dependency"} )
    delete "/source/home:tom:projectA?force=1"
    assert_response :success
    get "/source/home:tom:projectB/_meta"
    assert_response :success
    assert_xml_tag :tag => 'path', :attributes => { :project => "deleted", :repository => "deleted" }
    put "/source/home:tom:projectB/_meta", "<project name='home:tom:projectB'> <title/> <description/> </project>"
    assert_response :success

    # cleanup
    delete "/source/home:tom:projectB"
    assert_response :success
  end

  def test_delete_project_with_local_devel_packages
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:project/_meta", "<project name='home:tom:project'> <title/> <description/> <repository name='repoA'> <arch>i586</arch> </repository> </project>"
    assert_response :success
    put "/source/home:tom:project/A/_meta", "<package name='A' project='home:tom:project'> <title/> <description/></package>"
    assert_response :success
    put "/source/home:tom:project/B/_meta", "<package name='B' project='home:tom:project'> <title/> <description/> <devel package='A'/> </package>"
    assert_response :success
    put "/source/home:tom:project/C/_meta", "<package name='C' project='home:tom:project'> <title/> <description/> <devel package='B'/> </package>"
    assert_response :success
    # delete the project including the packages
    delete "/source/home:tom:project"
    assert_response :success
  end

  def test_devel_project_cycle
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:A/_meta", "<project name='home:tom:A'> <title/> <description/> </project>"
    assert_response :success
    put "/source/home:tom:B/_meta", "<project name='home:tom:B'> <title/> <description/> <devel project='home:tom:A'/> </project>"
    assert_response :success
    get "/source/home:tom:B/_meta"
    assert_response :success
    assert_xml_tag :tag => 'devel', :attributes => { :project => 'home:tom:A' }
    put "/source/home:tom:C/_meta", "<project name='home:tom:C'> <title/> <description/> <devel project='home:tom:B'/> </project>"
    assert_response :success
    # no self reference
    put "/source/home:tom:A/_meta", "<project name='home:tom:A'> <title/> <description/> <devel project='home:tom:A'/> </project>"
    assert_response 400
    # create a cycle via new package
    put "/source/home:tom:A/_meta", "<project name='home:tom:A'> <title/> <description/> <devel project='home:tom:C'/> </project>"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "project_cycle"} )
  end

  def test_devel_package_cycle
    prepare_request_with_user "tom", "thunder"
    raw_put "/source/home:tom/packageA/_meta", "<package project='home:tom' name='packageA'> <title/> <description/> </package>"
    assert_response :success
    raw_put "/source/home:tom/packageB/_meta", "<package project='home:tom' name='packageB'> <title/> <description/> <devel package='packageA' /> </package>"
    assert_response :success
    raw_put "/source/home:tom/packageC/_meta", "<package project='home:tom' name='packageC'> <title/> <description/> <devel package='packageB' /> </package>"
    assert_response :success
    # no self reference
    raw_put "/source/home:tom/packageA/_meta", "<package project='home:tom' name='packageA'> <title/> <description/> <devel package='packageA' /> </package>"
    assert_response 400
    # create a cycle via new package
    raw_put "/source/home:tom/packageB/_meta", "<package project='home:tom' name='packageB'> <title/> <description/> <devel package='packageC' /> </package>"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "devel_cycle"} )
    # create a cycle via existing package
    raw_put "/source/home:tom/packageA/_meta", "<package project='home:tom' name='packageA'> <title/> <description/> <devel package='packageB' /> </package>"
    assert_response 400
    assert_xml_tag( :tag => "status", :attributes => { :code => "devel_cycle"} )
  end

  def do_test_change_package_meta (project, package, response1, response2, tag2, response3, select3)
    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response1
    if !(response2 || tag2 || response3 || select3)
      #dummy write to check blocking
      raw_put url_for(:controller => :source, :action => :package_meta, :project => project, :package => package), 
              "<package name=\"#{package}\"><title></title><description></description></package>"
      assert_response 404
#      assert_match(/unknown_package/, @response.body)
      assert_match(/unknown_project/, @response.body)
      return
    end
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    b = d.add_element 'build'
    b.add_element 'enable'
    put url_for(:controller => :source, :action => :package_meta, :project => project, :package => package), doc.to_s
    assert_response response2
    assert_xml_tag(tag2)

    get url_for(:controller => :source, :action => :package_meta, :project => project, :package => package)
    assert_response response3
    assert_select select3 if select3
  end

  def test_change_package_meta
    prj="kde4"      # project
    pkg="kdelibs"   # package
    resp1=:success  # assert response #1
    resp2=:success  # assert response #2
    atag2={ :tag => "status", :attributes => { :code => "ok"} } # assert_xml_tag after response #2
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
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "."), doc.to_s
    assert_response 400
    assert_xml_tag :tag => "status", :child => { :content => %r{project validation error: Expecting element project} }
    
    #must not create a package with different pathname and name in _meta.xml:
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs2000"), doc.to_s
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "package_name_mismatch" }
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
    assert_xml_tag( :tag => "status" )
  end

  def test_read_file_hidden_proj
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/HiddenProject/pack/my_file"

    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_project"} 
    # uninvolved, 
    prepare_request_with_user "tom", "thunder"
    get "/source/HiddenProject/pack/my_file"
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_project"} 
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

  def test_read_filelist_sourceaccess_proj
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/SourceprotectedProject/pack"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
    # uninvolved, 
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
    # reader
    # downloader
    # maintainer
    prepare_request_with_user "sourceaccess_homer", "homer"
    get "/source/SourceprotectedProject/pack"
    assert_response :success
    assert_xml_tag :tag => "directory"
    # admin
    prepare_request_with_user "king", "sunflower"
    get "/source/SourceprotectedProject/pack"
    assert_response :success
    assert_xml_tag :tag => "directory"
  end

  def test_read_file_sourceaccess_proj
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
    # uninvolved, 
    prepare_request_with_user "tom", "thunder"
    get "/source/SourceprotectedProject/pack/my_file"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "source_access_no_permission"} 
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
    assert_xml_tag asserttag1 if asserttag1
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
    asserttag1={ :tag => 'status', :attributes => { :code => "unknown_project"} }
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

  def test_add_file_to_package_sourceaccess_protect
    # uninvolved user
    prepare_request_with_user "fredlibs", "geröllheimer"
    url1="/source/SourceprotectedProject/pack"
    url2="/source/SourceprotectedProject/pack/testfile"
    assertresp2=403
    assertselect2=nil
    assertselect2rev=nil
    assertresp3=403
    asserteq3=nil
    assertresp4=403
    add_file_to_package(url1, nil, url2, assertresp2, 
                               assertselect2, assertselect2rev, 
                               assertresp3, asserteq3, assertresp4)
    # nobody 
    prepare_request_with_user "adrian_nobody", "so_alone"
    add_file_to_package(url1, nil, url2, assertresp2, 
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
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :filename => "my_patch.diff")
    assert_response :success
    origstring = @response.body.to_s
    teststring = "&;"
    put url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :filename => "my_patch.diff"), teststring
    assert_response( 403, message="Was able to write a package file without permission" )
    assert_xml_tag( :tag => "status" )
    
    # check that content is unchanged: 
    get url_for(:controller => :source, :action => :file, :project => "kde4", :package => "kdelibs", :filename => "my_patch.diff")
    assert_response :success
    assert_equal( @response.body.to_s, origstring, message="Package file was changed without permissions" )

    # invalid permission
    reset_auth 
    delete "/source/kde4/kdelibs/my_patch.diff"
    assert_response 401

    prepare_request_with_user "adrian_nobody", "so_alone"
    delete "/source/kde4/kdelibs/my_patch.diff"
    assert_response 403
  
    get "/source/kde4/kdelibs/my_patch.diff"
    assert_response :success
  end
  
  def test_get_project_meta_history
    reset_auth 
    get "/source/kde4/_project/_history"
    assert_response 401
    prepare_request_with_user "fredlibs", "geröllheimer"
    get "/source/kde4/_project/_history"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
    get "/source/kde4/_project/_history?meta=1"
    assert_response :success
    assert_xml_tag( :tag => "revisionlist" )
  end

  def test_remove_and_undelete_operations
    reset_auth 
    delete "/source/kde4/kdelibs"
    assert_response 401
    delete "/source/kde4"
    assert_response 401

    # delete single package in project
    prepare_request_with_user "fredlibs", "geröllheimer"
    put "/source/kde4/kdelibs/DUMMYFILE", "dummy"
    assert_response :success
    # to have different revision number in meta and plain files
    delete "/source/kde4/kdelibs?user=illegal&comment=test%20deleted" 
    assert_response :success

    get "/source/kde4/kdelibs" 
    assert_response 404
    get "/source/kde4/kdelibs/_meta" 
    assert_response 404

    # check history
    get "/source/kde4/kdelibs/_history?deleted=1" 
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "user", :content => "fredlibs" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "test deleted" )
    get "/source/kde4/kdelibs/_history?meta=1&deleted=1" 
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "user", :content => "fredlibs" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "test deleted" )
    assert_response :success

    # list deleted packages of existing project
    get "/source/kde4", :deleted => 1
    assert_response :success
    assert_xml_tag( :tag => "entry", :attributes => { :name => "kdelibs"} )

    # access to files of a deleted package
    get "/source/kde4/kdelibs/_history"
    assert_response 404
    get "/source/kde4/kdelibs/_history", :deleted => 1
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    srcmd5 = node.each_revision.last.srcmd5.text 
    get "/source/kde4/kdelibs", :deleted => 1, :rev => srcmd5
    assert_response :success
    get "/source/kde4/kdelibs/my_patch.diff", :rev => srcmd5
    assert_response 404
    get "/source/kde4/kdelibs/my_patch.diff", :deleted => 1, :rev => srcmd5
    assert_response :success
    get "/source/kde4/kdelibs/my_patch.diff", :deleted => 1
    assert_response :success

    # undelete single package
    post "/source/kde4/kdelibs", :cmd => :undelete
    assert_response :success
    get "/source/kde4/kdelibs"
    assert_response :success
    get "/source/kde4/kdelibs/_meta"
    assert_response :success

    # delete entire project
    delete "/source/kde4?user=illegal&comment=drop%20project" 
    assert_response :success

    get "/source/kde4" 
    assert_response 404
    get "/source/kde4/_meta" 
    assert_response 404

    # list deleted packages of deleted project
# FIXME: not yet supported
#    get "/source/kde4", :deleted => 1
#    assert_response :success
#    assert_xml_tag( :tag => "entry", :attributes => { :name => "kdelibs"} )

    # list content of deleted project
    prepare_request_with_user "king", "sunflower"
    get "/source", :deleted => 1
    assert_response 200
    assert_xml_tag( :tag => "entry", :attributes => { :name => "kde4"} )
    prepare_request_with_user "fredlibs", "geröllheimer"
    get "/source", :deleted => 1
    assert_response 403
    assert_match(/only admins can see deleted projects/, @response.body)

    # check history
    get "/source/kde4/_project/_history?deleted=1" 
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "user", :content => "fredlibs" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "drop project" )
    get "/source/kde4/_project/_history?meta=1&deleted=1" 
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "user", :content => "fredlibs" )
    assert_xml_tag( :parent => { :tag => "revision" }, :tag => "comment", :content => "drop project" )
    assert_response :success

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
    delete "/source/kde4/kdelibs/DUMMYFILE" # restore as before
    assert_response :success

    # undelete project again
    post "/source/kde4", :cmd => :undelete
    assert_response 404
    assert_match(/project 'kde4' already exists/, @response.body)
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
    node = ActiveXML::Node.new(@response.body)
    assert_equal node.repository.name, "home_coolo"
    assert_equal node.repository.path.project, "deleted"
    assert_equal node.repository.path.repository, "deleted"
  end

  def test_diff_package
    prepare_request_with_user "tom", "thunder" 
    post "/source/home:Iggy/TestPack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
  end

  def test_meta_diff_package
    prepare_request_with_user "tom", "thunder" 
    post "/source/home:Iggy/TestPack?oproject=kde4&opackage=kdelibs&cmd=diff&meta=1"
    assert_response :success
    assert_match(/<\/package>/, @response.body)

    post "/source/home:Iggy/_project?oproject=kde4&opackage=_project&cmd=diff&meta=1"
    assert_response :success
    assert_match(/<\/project>/, @response.body)
  end

  def test_diff_package_hidden_project
    prepare_request_with_user "tom", "thunder"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => "unknown_project"}
    #reverse
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { :code => "unknown_project"} # was package

    prepare_request_with_user "hidden_homer", "homer"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match(/Minimal rpm package for testing the build controller/, @response.body)
    # reverse
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match(/argl/, @response.body)

    prepare_request_with_user "king", "sunflower"
    post "/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match(/Minimal rpm package for testing the build controller/, @response.body)
    # reverse
    prepare_request_with_user "king", "sunflower"
    post "/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match(/argl/, @response.body)
  end

  def test_diff_package_sourceaccess_protected_project
    prepare_request_with_user "tom", "thunder"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { :code => "source_access_no_permission"}
    #reverse
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { :code => "source_access_no_permission"}

    prepare_request_with_user "sourceaccess_homer", "homer"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match(/Protected Content/, @response.body)
    # reverse
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match(/argl/, @response.body)

    prepare_request_with_user "king", "sunflower"
    post "/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff"
    assert_response :success
    assert_match(/Protected Content/, @response.body)
    # reverse
    prepare_request_with_user "king", "sunflower"
    post "/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff"
    assert_response :success
    assert_match(/argl/, @response.body)
  end

  def test_constraints
    prepare_request_with_user "tom", "thunder"
    get "/source/home:coolo:test"
    assert_response :success
    put "/source/home:coolo:test/_project/_constraints", "illegal"
    assert_response 400
    assert_match(/validation error/, @response.body)
    put "/source/home:coolo:test/_project/_constraints", "<constraints> <hardware> <processors>3</processors> </hardware> </constraints>"
    assert_response :success
    put "/source/home:coolo:test/test/_meta", "<package project='home:coolo:test' name='test'><title/><description/></package>"
    assert_response :success
    put "/source/home:coolo:test/test/_constraints", "<constraints> <linux> <version><min>1.0</min></version> </linux> </constraints>"
    assert_response :success

    # cleanup
    delete "/source/home:coolo:test/_project/_constraints"
    assert_response :success
    delete "/source/home:coolo:test/test"
    assert_response :success
  end

  def test_pattern
    reset_auth 
    put "/source/kde4/_pattern/mypattern", load_backend_file("pattern/digiKam.xml")
    assert_response 401

    prepare_request_with_user "adrian_nobody", "so_alone"
    get "/source/DoesNotExist/_pattern"
    assert_response 404
    get "/source/kde4/_pattern"
    assert_response :success
    get "/source/kde4/_pattern/DoesNotExist"
    assert_response 404
    put "/source/kde4/_pattern/mypattern", load_backend_file("pattern/digiKam.xml")
    assert_response 403
    assert_match(/put_file_no_permission/, @response.body)

    prepare_request_with_user "tom", "thunder"
    get "/source/home:coolo:test"
    assert_response :success
    assert_no_match(/_pattern/, @response.body)
    put "/source/home:coolo:test/_pattern/mypattern", "broken"
    assert_response 400
    assert_match(/validation error/, @response.body)
    put "/source/home:coolo:test/_pattern/mypattern", load_backend_file("pattern/digiKam.xml")
    assert_response :success
    get "/source/home:coolo:test/_pattern/mypattern"
    assert_response :success
    get "/source/home:coolo:test"
    assert_response :success
    assert_match(/_pattern/, @response.body)

    # delete failure
    prepare_request_with_user "adrian_nobody", "so_alone"
    delete "/source/home:coolo:test/_pattern/mypattern"
    assert_response 403

    # successfull delete
    prepare_request_with_user "tom", "thunder"
    delete "/source/home:coolo:test/_pattern/mypattern"
    assert_response :success
    delete "/source/home:coolo:test/_pattern/mypattern"
    assert_response 404
    delete "/source/home:coolo:test/_pattern"
    assert_response :success
    delete "/source/home:coolo:test/_pattern"
    assert_response 404
  end

  def test_prjconf
    reset_auth 
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
    reset_auth 
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
    # listings
    get "/source/BaseDistro2.0:LinkedUpdateProject"
    assert_response :success
    assert_xml_tag( :tag => "directory", :attributes => { :count => "0" } )
    get "/source/BaseDistro2.0:LinkedUpdateProject?expand=1"
    assert_response :success
    assert_xml_tag( :tag => "directory", :attributes => { :count => "2" } )
    assert_xml_tag( :tag => "entry", :attributes => { :name => "pack2", :originproject => "BaseDistro2.0" } )
    assert_xml_tag( :tag => "entry", :attributes => { :name => "pack2_linked", :originproject => "BaseDistro2.0" } )

    # pack2 exists only via linked project
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2"
    assert_response :success
    delete "/source/BaseDistro2.0:LinkedUpdateProject/pack2"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    # test not permitted commands
    post "/build/BaseDistro2.0:LinkedUpdateProject", :cmd => "rebuild"
    assert_response 403
    post "/build/BaseDistro2.0:LinkedUpdateProject", :cmd => "wipe"
    assert_response 403
    assert_match(/permission to execute command on project BaseDistro2.0:LinkedUpdateProject/, @response.body)
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "deleteuploadrev"
    assert_response 404
    assert_match(/unknown_package/, @response.body)
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "commitfilelist"
    assert_response 404
    assert_match(/unknown_package/, @response.body)
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "commit"
    assert_response 404
    assert_match(/unknown_package/, @response.body)
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "linktobranch"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    # test permitted commands
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "diff", :oproject => "RemoteInstance:BaseDistro", :opackage => "pack1"
    assert_response :success
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "branch"
    assert_response :success
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2_linked", :cmd => "linkdiff"
    assert_response :success

    # read-write user, binary operations must be allowed
    prepare_request_with_user "king", "sunflower"
    # obsolete with OBS 3.0, rebuild only via /build/
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "rebuild"
    assert_response :success
    post "/build/BaseDistro2.0:LinkedUpdateProject", :cmd => "rebuild", :package => "pack2"
    assert_response :success
    post "/build/BaseDistro2.0:LinkedUpdateProject", :cmd => "wipe"
    assert_response :success

    # create package and remove it again
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2"
    assert_response :success
    delete "/source/BaseDistro2.0:LinkedUpdateProject/pack2"
    assert_response 404
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "copy", :oproject => "BaseDistro:Update", :opackage => "pack2"
    assert_response :success
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "undelete"
    assert_response 404
    assert_match(/package_exists/, @response.body)
    delete "/source/BaseDistro2.0:LinkedUpdateProject/pack2"
    assert_response :success
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "undelete"
    assert_response :success
  end

  def test_linktobranch
    prepare_request_with_user "Iggy", "asdfasdf"
    put "/source/home:Iggy/TestLinkPack/_meta", "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success
    put "/source/home:Iggy/TestLinkPack/_link", "<link package='TestPack' />"
    assert_response :success

    prepare_request_with_user "fred", "geröllheimer"
    post "/source/home:Iggy/TestLinkPack?cmd=linktobranch"
    assert_response 403

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/home:Iggy/TestLinkPack?cmd=linktobranch"
    assert_response :success
    get "/source/home:Iggy/TestLinkPack/_link"
    assert_response :success
    assert_xml_tag( :tag => "link", :attributes => { :package => "TestPack" } )
    assert_xml_tag( :parent => { :tag => "patches", :content => nil }, :tag => "branch", :content => nil )

    delete "/source/home:Iggy/TestLinkPack"
    assert_response :success
  end

  def test_copy_package
    # fred has maintainer permissions in this single package of Iggys home
    # this is the osc way
    prepare_request_with_user "fred", "geröllheimer"
    put "/source/home:Iggy/TestPack/filename", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/TestPack/_history"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    revision = node.each_revision.last.value :rev

    # standard copy
    post "/source/home:fred/DELETE", :cmd => :copy, :oproject => "home:Iggy", :opackage => "TestPack"
    assert_response :success
    get "/source/home:fred/DELETE/_history"
    assert_response :success
    assert_xml_tag :tag => "revisionlist", :children => { :count => 1 }

# FIXME: this is not yet supported in backend
if $ENABLE_BROKEN_TEST
    # copy with history
    post "/source/home:fred/DELETE", :cmd => :copy, :oproject => "home:Iggy", :opackage => "TestPack", :withhistory => "1"
    assert_response :success
    get "/source/home:fred/DELETE/_history"
    assert_response :success
    assert_xml_tag :tag => "revisionlist", :children => { :count => revision }
end

    # cleanup
    delete "/source/home:fred/DELETE"
    assert_response :success
    delete "/source/home:Iggy/TestPack/filename"
    assert_response :success
  end

  def test_copy_project
    # NOTE: copy tests for release projects are part of maintenance tests
    prepare_request_with_user "fred", "geröllheimer"
    get "/source/home:Iggy/_meta"
    assert_response :success
    assert_xml_tag :tag => "person", :attributes => { :userid => "Iggy", :role => "maintainer" }
    orig = @response.body
    post "/source/home:fred:COPY", :cmd => :copy, :oproject => "home:Iggy"
    assert_response :success
    get "/source/home:fred:COPY/_meta"
    assert_response :success
    assert_no_xml_tag :tag => "person", :attributes => { :userid => "Iggy" }
    assert_xml_tag :tag => "person", :attributes => { :userid => "fred", :role => "maintainer" }
    copy = @response.body
    # almost everything must be identical
    orig = orig.gsub(/project name=.*/, 'project') # make project name identical
    copy = copy.gsub(/project name=.*/, 'project')
    orig = orig.gsub(/.*<person.*\n/, '') # remove all person lines, they have to differ
    copy = copy.gsub(/.*<person.*\n/, '')
    assert_equal copy, orig

    # permissions
    # create new project is not allowed
    post "/source/TEMPCOPY", :cmd => :copy, :oproject => "home:Iggy", :nodelay => "1"
    assert_response 403
    assert_xml_tag( :tag => "status", :attributes => { :code => "cmd_execution_no_permission"} )
    prepare_request_with_user "king", "sunflower"
    put "/source/TEMPCOPY/_meta", '<project name="TEMPCOPY"> <title/> <description/> <person role="maintainer" userid="fred"/> </project>'
    assert_response :success
    # copy into existing project is allowed
    prepare_request_with_user "fred", "geröllheimer"
    post "/source/TEMPCOPY", :cmd => :copy, :oproject => "home:Iggy"
    assert_response :success

    # cleanup
    delete "/source/TEMPCOPY"
    assert_response :success
  end

  def test_source_commits
    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy/TestPack", :cmd => "commitfilelist"
    assert_response 403
    put "/source/home:Iggy/TestPack/filename", 'CONTENT'
    assert_response 403

    # fred has maintainer permissions in this single package of Iggys home
    # this is the osc way
    prepare_request_with_user "fred", "geröllheimer"
    delete "/source/home:Iggy/TestPack/filename" # in case other tests created it
    put "/source/home:Iggy/TestPack/filename?rev=repository", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/TestPack/filename"
    assert_response 404
    get "/source/home:Iggy/TestPack/_history?limit=1"
    assert_response :success
    assert_xml_tag :tag => "revisionlist", :children => { :count => 1 }
    get "/source/home:Iggy/TestPack/_history"
    assert_response :success
    assert_no_xml_tag :tag => "revisionlist", :children => { :count => 1 }
    node = ActiveXML::Node.new(@response.body)
    revision = node.each_revision.last.value :rev
    revision = revision.to_i + 1
    post "/source/home:Iggy/TestPack?cmd=commitfilelist", ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get "/source/home:Iggy/TestPack/filename"
    assert_response :success
    get "/source/home:Iggy/TestPack/_history"
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision", :attributes => { :rev => revision.to_s}, :content => nil }, :tag => "user", :content => "fred" )
    assert_xml_tag( :parent => { :tag => "revision", :attributes => { :rev => revision.to_s}, :content => nil }, :tag => "srcmd5" )

    # delete file with commit
    delete "/source/home:Iggy/TestPack/filename"
    assert_response :success
    revision = revision.to_i + 1
    get "/source/home:Iggy/TestPack/filename"
    assert_response 404

    # this is the future webui way
    prepare_request_with_user "fred", "geröllheimer"
    put "/source/home:Iggy/TestPack/filename?rev=upload", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/TestPack/filename"
    assert_response :success
    get "/source/home:Iggy/TestPack/filename?rev=latest"
    assert_response 404
    get "/source/home:Iggy/TestPack/_history"
    assert_response :success
    revision = revision.to_i + 1
    assert_no_xml_tag( :tag => "revision", :attributes => { :rev => revision.to_s} )
    post "/source/home:Iggy/TestPack?cmd=commit"
    assert_response :success
    get "/source/home:Iggy/TestPack/filename?rev=latest"
    assert_response :success
    get "/source/home:Iggy/TestPack/_history"
    assert_response :success
    assert_xml_tag( :parent => { :tag => "revision", :attributes => { :rev => revision.to_s}, :content => nil }, :tag => "user", :content => "fred" )
    assert_xml_tag( :parent => { :tag => "revision", :attributes => { :rev => revision.to_s}, :content => nil }, :tag => "srcmd5" )


    # test deleteuploadrev
    put "/source/home:Iggy/TestPack/anotherfilename?rev=upload", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/TestPack/anotherfilename"
    assert_response :success
    get "/source/home:Iggy/TestPack/anotherfilename?rev=latest"
    assert_response 404
    post "/source/home:Iggy/TestPack?cmd=deleteuploadrev"
    assert_response :success
    get "/source/home:Iggy/TestPack/anotherfilename"
    assert_response 404

    #
    # Test commits to special packages
    #
    prepare_request_with_user "Iggy", "asdfasdf"
    # _product must be created
    put "/source/home:Iggy/_product/_meta", "<package project='home:Iggy' name='_product'> <title/> <description/> </package>"
    assert_response :success
    put "/source/home:Iggy/_product/filename?rev=repository", 'CONTENT'
    assert_response :success
    post "/source/home:Iggy/_product?cmd=commitfilelist", ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get "/source/home:Iggy/_product/filename"
    assert_response :success
    put "/source/home:Iggy/_product/filename2", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/_product/filename2"
    assert_response :success

    # _pattern exists always
    put "/source/home:Iggy/_pattern/filename", 'CONTENT'
    assert_response 400 # illegal content
    put "/source/home:Iggy/_pattern/filename?rev=repository", load_backend_file("pattern/digiKam.xml")
    assert_response :success
    post "/source/home:Iggy/_pattern?cmd=commitfilelist", ' <directory> <entry name="filename" md5="c5fadc30cd4c7d45bd3ce053b2751ec2" /> </directory> '
    assert_response :success
    get "/source/home:Iggy/_pattern/filename"
    assert_response :success
    put "/source/home:Iggy/_pattern/filename2", load_backend_file("pattern/digiKam.xml")
    assert_response :success
    get "/source/home:Iggy/_pattern/filename2"
    assert_response :success

    # _project exists always
    put "/source/home:Iggy/_project/filename?rev=repository", 'CONTENT'
    assert_response :success
    post "/source/home:Iggy/_project?cmd=commitfilelist", ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get "/source/home:Iggy/_project/filename"
    assert_response :success
    put "/source/home:Iggy/_project/filename2", 'CONTENT'
    assert_response :success
    get "/source/home:Iggy/_project/filename2"
    assert_response :success
  end

  def test_list_of_linking_instances
    prepare_request_with_user "tom", "thunder"

    # list all linking projects
    post "/source/BaseDistro2.0", :cmd => "showlinked"
    assert_response :success
    assert_xml_tag( :tag => "project", :attributes => { :name => "BaseDistro2.0:LinkedUpdateProject"}, :content => nil )

    # list all linking packages with a local link
    post "/source/BaseDistro/pack2", :cmd => "showlinked"
    assert_response :success
    assert_xml_tag( :tag => "package", :attributes => { :project => "BaseDistro:Update", :name => "pack2" }, :content => nil )

    # list all linking packages, base package is a package on a remote OBS instance
# FIXME: support for this search is possible, but not yet implemented
#    post "/source/RemoteInstance:BaseDistro/pack", :cmd => "showlinked"
#    assert_response :success
#    assert_xml_tag( :tag => "package", :attributes => { :project => "BaseDistro:Update", :name => "pack2" }, :content => nil )
  end

  def test_create_links
    prepare_request_with_user "king", "sunflower"
    put url_for(:controller => :source, :action => :project_meta, :project => "TEMPORARY"), 
        '<project name="TEMPORARY"> <title/> <description/> <person role="maintainer" userid="fred"/> </project>'
    assert_response 200
    # create packages via user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary"), 
        '<package project="kde4" name="temporary"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "temporary2"), 
        '<package project="kde4" name="temporary2"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )
    put "/source/kde4/temporary/file_in_linked_package", 'FILE CONTENT'
    assert_response 200
    put url_for(:controller => :source, :action => :package_meta, :project => "TEMPORARY", :package => "temporary2"), 
        '<package project="TEMPORARY" name="temporary2"> <title/> <description/> </package>'
    assert_response 200

    url = "/source/kde4/temporary/_link"
    url2 = "/source/kde4/temporary2/_link"
    url3 = "/source/TEMPORARY/temporary2/_link"

    # illegal targets
    put url, '<link project="notexisting" />'
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_project" }
    put url, '<link project="kde4" package="notexiting" />'
    assert_response 404
    assert_xml_tag :tag => "status", :attributes => { :code => "unknown_package" }

    # not existing link target, but ignore it
    put url, '<link project="kde4" package="notexiting" missingok="true" />'
    assert_response :success
    put url, '<link project="BaseDistro" package="pack1" missingok="true" />'
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "not_missing" }

    # working local link
    put url, '<link project="BaseDistro" package="pack1" />'
    assert_response :success
    put url2, '<link package="temporary" />'
    assert_response :success
    put url3, '<link project="kde4" />'
    assert_response :success

    # working link to package via project link
    put url, '<link project="BaseDistro2.0:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote package
    put url, '<link project="RemoteInstance:BaseDistro" package="pack1" />'
    assert_response :success
    put url, '<link project="RemoteInstance:BaseDistro2.0:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote project link
    put url, '<link project="UseRemoteInstance" package="pack1" />'
    assert_response :success

    # check backend functionality
    get "/source/kde4/temporary"
    assert_response :success
    assert_no_xml_tag( :tag => "entry", :attributes => {:name => "my_file"} )
    assert_xml_tag( :tag => "entry", :attributes => {:name => "file_in_linked_package"} )
    assert_xml_tag( :tag => "entry", :attributes => {:name => "_link"} )
    assert_xml_tag( :tag => "linkinfo", :attributes => {:project => "UseRemoteInstance",  :package => "pack1",
                :srcmd5 => "96c3955b419fec1a637698e52b6a7d37", :xsrcmd5 => "6660e7c304ba16c50a415617bacb8b2f", :lsrcmd5 => "eabf686413b92c976ea073b11d797a2e"} )
    get "/source/kde4/temporary2?expand=1"
    assert_response :success
    assert_xml_tag( :tag => "entry", :attributes => {:name => "my_file"} )
    assert_xml_tag( :tag => "entry", :attributes => {:name => "file_in_linked_package"} )
    assert_xml_tag( :tag => "linkinfo", :attributes => {:project => "kde4",  :package => "temporary"} )
    assert_no_xml_tag( :tag => "entry", :attributes => {:name => "_link"} )
    get "/source/TEMPORARY/temporary2?expand=1"
    assert_response :success
    assert_xml_tag( :tag => "entry", :attributes => {:name => "my_file"} )
    assert_xml_tag( :tag => "entry", :attributes => {:name => "file_in_linked_package"} )
    assert_xml_tag( :tag => "linkinfo", :attributes => {:project => "kde4",  :package => "temporary2"} )
    assert_no_xml_tag( :tag => "entry", :attributes => {:name => "_link"} )

    # cleanup
    delete "/source/kde4/temporary"
    assert_response :success
    delete "/source/kde4/temporary2"
    assert_response :success
    prepare_request_with_user "king", "sunflower"
    delete "/source/TEMPORARY"
    assert_response :success
  end

  def test_create_project_with_invalid_repository_reference
    prepare_request_with_user "tom", "thunder"
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me" />
         </project>'
    assert_response :success
    # self reference
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me">
             <path project="home:tom:temporary" repository="me" />
           </repository>
         </project>'
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "package_save_error" }
    assert_match(/Using same repository as path element is not allowed/, @response.body)
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me">
             <hostsystem project="home:tom:temporary" repository="me" />
           </repository>
         </project>'
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "package_save_error" }
    assert_match(/Using same repository as hostsystem element is not allowed/, @response.body)
    # not existing repo
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me">
             <path project="home:tom:temporary" repository="DOESNOTEXIST" />
           </repository>
         </project>'
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "package_save_error" }
    assert_match(/unable to walk on path/, @response.body)
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me">
             <hostsystem project="home:tom:temporary" repository="DOESNOTEXIST" />
           </repository>
         </project>'
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => "package_save_error" }
    assert_match(/Unknown target repository/, @response.body)

    delete "/source/home:tom:temporary"
    assert_response :success
  end

  def test_use_project_link_as_non_maintainer
    prepare_request_with_user "tom", "thunder"
    put url_for(:controller => :source, :action => :project_meta, :project => "home:tom:temporary"), 
        '<project name="home:tom:temporary"> <title/> <description/> <link project="kde4" /> </project>'
    assert_response :success
    get "/source/home:tom:temporary"
    assert_response :success
    get "/source/home:tom:temporary/kdelibs"
    assert_response :success
    get "/source/home:tom:temporary/kdelibs/_history"
    assert_response :success
    delete "/source/home:tom:temporary/kdelibs"
    assert_response 404
    post "/source/home:tom:temporary/kdelibs", :cmd => :copy, :oproject => "home:tom:temporary", :opackage => "kdelibs"
    assert_response :success
    get "/source/home:tom:temporary/kdelibs/_meta"
    meta = @response.body
    assert_response :success
    delete "/source/home:tom:temporary/kdelibs"
    assert_response :success
    delete "/source/home:tom:temporary/kdelibs"
    assert_response 404

    # check if package creation is doing the right thing
    put "/source/home:tom:temporary/kdelibs/_meta", meta.dup
    assert_response :success
    delete "/source/home:tom:temporary/kdelibs"
    assert_response :success
    delete "/source/home:tom:temporary/kdelibs"
    assert_response 404

    # cleanup
    delete "/source/home:tom:temporary"
    assert_response :success
  end

  def test_delete_and_undelete_permissions
    reset_auth 
    delete "/source/kde4/kdelibs"
    assert_response 401
    delete "/source/kde4"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    delete "/source/kde4/kdelibs"
    assert_response 403
    delete "/source/kde4"
    assert_response 403

    prepare_request_with_user "adrian", "so_alone"
    delete "/source/kde4/kdelibs"
    assert_response :success
    delete "/source/kde4"
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/kde4", :cmd => :undelete
    assert_response 403

    prepare_request_with_user "adrian", "so_alone"
    post "/source/kde4", :cmd => :undelete
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    post "/source/kde4", :cmd => :undelete
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/kde4/kdelibs", :cmd => :undelete
    assert_response 403

    prepare_request_with_user "adrian", "so_alone"
    post "/source/kde4/kdelibs", :cmd => :undelete
    assert_response :success
  end

  def test_branch_package_delete_and_undelete
    reset_auth 
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 401
    prepare_request_with_user "fredlibs", "geröllheimer"
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "NotExisting"
    assert_response 403
    assert_match(/no permission to create project/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"
    assert_response 403
    assert_match(/no permission to/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :force => "1" 
    assert_response 403
    assert_match(/no permission to/, @response.body)
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test", :dryrun => "1" 
    assert_response :success
    assert_xml_tag :tag => 'package', :attributes => {:package => 'TestPack', :project => 'home:Iggy'},
                                  :child => { :tag => 'target', :attributes => {:package => 'TestPack', :project => 'home:coolo:test'} }
 
    prepare_request_with_user "tom", "thunder"
    post "/source/home:Iggy/TestPack", :cmd => :branch, :target_project => "home:coolo:test"    
    assert_response :success
    get "/source/home:coolo:test/TestPack/_meta"
    assert_response :success

    # branch again
    get "/source/home:coolo:test/_meta"
    assert_response :success
    oldmeta = @response.body
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
    # project meta must be untouched
    get "/source/home:coolo:test/_meta"
    assert_response :success
    assert_equal oldmeta, @response.body
    # FIXME: do a real commit and branch afterwards

    # now with a new project
    post "/source/home:Iggy/TestPack", :cmd => :branch
    assert_response :success
    
    get "/source/home:tom:branches:home:Iggy/TestPack/_meta"
    assert_response :success

    get "/source/home:tom:branches:home:Iggy/_meta"
    ret = ActiveXML::Node.new @response.body
    assert_equal ret.repository.name, "10.2"
    assert_equal ret.repository.path.repository, "10.2"
    assert_equal ret.repository.path.project, "home:Iggy"

    # check source link
    get "/source/home:tom:branches:home:Iggy/TestPack/_link"
    assert_response :success
    ret = ActiveXML::Node.new @response.body
    assert_equal ret.project, "home:Iggy"
    assert_nil ret.package
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # Branch a package with a defined devel package
    post "/source/kde4/kdelibs", :cmd => :branch
    assert_response :success
    assert_xml_tag( :tag => "data", :attributes => { :name => "targetproject"}, :content => "home:tom:branches:home:coolo:test" )
    assert_xml_tag( :tag => "data", :attributes => { :name => "targetpackage"}, :content => "kdelibs_DEVEL_package" )
    assert_xml_tag( :tag => "data", :attributes => { :name => "sourceproject"}, :content => "home:coolo:test" )
    assert_xml_tag( :tag => "data", :attributes => { :name => "sourcepackage"}, :content => "kdelibs_DEVEL_package" )

    # delete package
    reset_auth 
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
    assert_response 404

  end

  def test_package_set_flag
    prepare_request_with_user "Iggy", "asdfasdf"

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    original = @response.body

    post "/source/home:unknown/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/unknown_project/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=enable"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

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
    assert_xml_tag :tag => "status", :attributes => { :code => "delete_package_no_permission" }

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

    get "/source/home:Iggy/_meta?view=flagdetails"
    assert_response :success
    assert_xml_tag tag: "disable", attributes: { "explicit" => "1", "arch" => "i586", "repository" => "10.2" }, parent: { tag: "build" }

    post "/source/home:unknown?cmd=set_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404

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
    assert_match(/unknown_project/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    post "/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.2&arch=i586&flag=shine"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/TestPack/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "delete_package_no_permission" }

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
    assert_match(/unknown_project/, @response.body)

    post "/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    post "/source/home:Iggy?cmd=remove_flag&repository=10.2&arch=i586&flag=shine"
    assert_response 400
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get "/source/home:Iggy/_meta"
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post "/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo"
    assert_response 403
    assert_xml_tag :tag => "status", :attributes => { :code => "delete_package_no_permission" }

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
   
    Suse::Backend.put( '/source/home:Iggy/TestPack/bnc%23620675.diff', 'argl')
    assert_response :success

    get "/source/home:Iggy/TestPack"
    assert_response :success

    assert_xml_tag :tag => "directory", :child => { :tag => "entry" }
    assert_xml_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry", :attributes => { :name => "bnc#620675.diff" } } }

    get "/source/home:Iggy/TestPack/bnc%23620675.diff"
    assert_response :success

    #cleanup
    delete "/source/home:Iggy/TestPack/bnc%23620675.diff"
    assert_response :success
  end

  def draft_xml_for_duplicate_test(package_or_project)
    # first we add a bugowner
    if package_or_project == 'package'
      xml = "<package project='home:Iggy' name='TestPack'>"
    else
      xml = "<project name='home:Iggy'>"
    end
    xml += "<title>Strange XML</title><description></description>"
    # make sure never to erase ourselves
    xml += "<person userid='Iggy' role='maintainer'/>"
    xml += yield
    xml += "</#{package_or_project}>"
  end

  def duplicated_user_test(package_or_project, user_or_group, url)
    prepare_request_with_user "Iggy", "asdfasdf"
    
    xml = draft_xml_for_duplicate_test(package_or_project) do
      if user_or_group == 'user'
        "<person userid='tom' role='bugowner'/>"
      else
        "<group groupid='test_group' role='bugowner'/>"
      end
    end
    
    put url, xml
    assert_response :success
    
    # then we add two times the maintainer
    xml = draft_xml_for_duplicate_test(package_or_project) do
      if user_or_group == 'user'
        "<person userid='tom' role='bugowner'/>
         <person userid='tom' role='maintainer'/>
         <person userid='tom' role='maintainer'/>"
      else
        "<group groupid='test_group' role='bugowner'/>
         <group groupid='test_group' role='maintainer'/>
         <group groupid='test_group' role='maintainer'/>"
      end
    end

    put url, xml
    assert_response :success

    get url
    return Xmlhash.parse(@response.body)
  end

  test "have the same user role twice in package meta" do
    ret = duplicated_user_test("package", "user", "/source/home:Iggy/TestPack/_meta")
    assert_equal({"name"=>"TestPack",
                   "project"=>"home:Iggy",
                   "title"=>"Strange XML",
                   "description"=>{},
                   "person"=>
                   [{"userid"=>"tom", "role"=>"maintainer"},
                    {"userid"=>"tom", "role"=>"bugowner"},
                    {"userid"=>"Iggy", "role"=>"maintainer"}]}, ret)

    ret = duplicated_user_test("package", "group", "/source/home:Iggy/TestPack/_meta")
    assert_equal({"name"=>"TestPack",
                   "project"=>"home:Iggy",
                   "title"=>"Strange XML",
                   "description"=>{},
                   "person"=>{"userid"=>"Iggy", "role"=>"maintainer"},
                   "group"=>
                   [{"groupid"=>"test_group", "role"=>"maintainer"},
                    {"groupid"=>"test_group", "role"=>"bugowner"}]}, ret)

    ret = duplicated_user_test("project", "user", "/source/home:Iggy/_meta")
    assert_equal({"name"=>"home:Iggy",
                   "title"=>"Strange XML",
                   "description"=>{},
                   "person"=>
                   [{"userid"=>"tom", "role"=>"maintainer"},
                    {"userid"=>"tom", "role"=>"bugowner"},
                    {"userid"=>"Iggy", "role"=>"maintainer"}]}, ret)
                 
    ret = duplicated_user_test("project", "group", "/source/home:Iggy/_meta")
    assert_equal({"name"=>"home:Iggy",
                   "title"=>"Strange XML",
                   "description"=>{},
                   "person"=>{"userid"=>"Iggy", "role"=>"maintainer"},
                   "group"=>
                   [{"groupid"=>"test_group", "role"=>"maintainer"},
                    {"groupid"=>"test_group", "role"=>"bugowner"}]}, ret)
  end

  test "store invalid package" do
    prepare_request_with_user "tom", "thunder"
    name = Faker::Lorem.characters(255)
    url = url_for(controller: :source, action: :package_meta, project: "home:tom", package: name)
    put url, "<package name='#{name}' project='home:tom'> <title/> <description/></package>"
    assert_response 400
    # FIXME2.4 assert_select "status[code] > summary", %r{Name is too long}
    get url
    assert_response 404
  end
  
  test "store invalid project" do
    prepare_request_with_user "tom", "thunder" 
    name = "home:tom:#{Faker::Lorem.characters(255)}"
    url = url_for(controller: :source, action: :project_meta, project: name)
    put url, "<project name='#{name}'> <title/> <description/></project>"
    assert_response 400
    # FIXME2.4 assert_select "status[code] > summary", %r{Name is too long}
    get url 
    assert_response 404
  end

end
