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
    assert_no_match /entry name="HiddenProject"/, @response.body if $ENABLE_BROKEN_TEST
    #retry with maintainer
    ActionController::IntegrationTest::reset_auth
    prepare_request_with_user "adrian", "so_alone"
    get "/source"
    assert_response :success 
    assert_match /entry name="HiddenProject"/, @response.body if $ENABLE_BROKEN_TEST
  end

  def test_get_projectlist_with_privacy_protected_project
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

  def test_get_packagelist_with_hidden_packages
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

  def test_get_project_meta_from_protected_project
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
  
  def test_get_package_meta
    prepare_request_with_user "tom", "thunder"
    get "/source/kde4/kdelibs/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "kdelibs" }
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
    # admin
    prepare_request_with_user "king", "sunflower"
    do_change_project_meta_test
    # maintainer 
    prepare_request_with_user "fred", "geröllheimer"
    do_change_project_meta_test
    # maintainer via group
    prepare_request_with_user "adrian", "so_alone"
    do_change_project_meta_test
  end
  

  def do_change_project_meta_test
   # Get meta file  
    get url_for(:controller => :source, :action => :project_meta, :project => "kde4")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:action => :project_meta, :project => "kde4"), doc.to_s
    assert_response :success
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that it is the changed data
    get url_for(:action => :project_meta, :project => "kde4")
    doc = REXML::Document.new( @response.body )
    d = doc.elements["//description"]
    assert_equal new_desc, d.text
  
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



  def do_change_package_meta_test
   # Get meta file  
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s
    assert_response(:success, "--> Was not able to update kdelibs _meta")   
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    # Get data again and check that it is the changed data
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["//description"]
    #ignore updated change
    newdoc.root.attributes['updated'] = doc.root.attributes['updated']
    assert_equal new_desc, d.text
    assert_equal doc.to_s, newdoc.to_s
  end
  private :do_change_package_meta_test



  # admins, project-maintainer and package maintainer can edit package data
  def test_put_package_meta
      # admin
      prepare_request_with_user "king", "sunflower"
      do_change_package_meta_test
      # maintainer via user
      prepare_request_with_user "fred", "geröllheimer"
      do_change_package_meta_test
      prepare_request_with_user "fredlibs", "geröllheimer"
      do_change_package_meta_test
      # maintainer via group
      prepare_request_with_user "adrian", "so_alone"
      do_change_package_meta_test
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


  def test_change_package_meta
    # user without any special roles
    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    b = d.add_element 'build'
    b.add_element 'enable'
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs"), doc.to_s
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "kdelibs")
    assert_response :success
    assert_select "package > build > enable"
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
  
  def add_file_to_package
    get "/source/kde4/kdelibs"
    # before md5
    assert_tag :tag => 'directory', :attributes => { :srcmd5 => "1636661d96a88cd985d82dc611ebd723" }
    teststring = '&;'
    put "/source/kde4/kdelibs/testfile", teststring
    assert_response :success
    # afterwards new md5
    assert_select "revision > srcmd5", 'bc1d31b2403fa8925b257101b96196ec'
  
    get "/source/kde4/kdelibs/testfile"
    assert_response :success
    assert_equal teststring, @response.body

    delete "/source/kde4/kdelibs/testfile"
    assert_response :success
  
    get "/source/kde4/kdelibs/testfile"
    assert_response 404
  end
  private :add_file_to_package
  
  
  
  def test_add_file_to_package
    prepare_request_with_user "fredlibs", "geröllheimer"
    add_file_to_package
    prepare_request_with_user "fred", "geröllheimer"
    add_file_to_package
    prepare_request_with_user "king", "sunflower"
    add_file_to_package
  
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
#    print "\n #{@response.body}\n"
    assert_response response
    get "/source/#{targetproject}/pack/_meta"
#    print "\n #{@response.body}\n"
    assert_response response
    get "/source/#{targetproject}/pack/my_file"
#    print "\n #{@response.body}\n"
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
