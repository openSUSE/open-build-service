require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

class SourceControllerTest < Test::Unit::TestCase
  fixtures :static_permissions, :roles, :roles_static_permissions, :roles_users, :users
  
  def setup
    @controller = SourceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # make a backup of the XML test files
    # backup_source_test_data
  end

  def test_get_projectlist
    prepare_request_with_user @request, "tom", "thunder"
    get :index
    assert_response :success
    assert_tag :tag => "directory", :child => { :tag => "entry" }
    assert_tag :tag => "directory",
      :children => { :count => 1, :only => { :tag => "entry" } }
  end
  

  #def test_get_project_filelist
  #  get :file, :project => "kde4" 
  #  assert_response :success
  #  assert_tag :tag => "directory", :child => { :tag => "entry" }
  #  assert_tag :tag => "directory",
  #    :children => { :count => 2, :only => { :tag => "entry" } }
  #end


  # non-existing project should return 404
  def test_get_illegal_project
    prepare_request_with_user @request, "tom", "thunder"
    get :project_meta, :project => "kde2000" 
    assert_response 404
  end


  # non-existing project-package should return 404
  def test_get_illegal_projectfile
    prepare_request_with_user @request, "tom", "thunder"
    get :package_meta, :project => "kde4", :package => "kdelibs2000"
    assert_response 404
  end


  def test_get_project_meta
    prepare_request_with_user @request, "tom", "thunder"
    get :project_meta, :project => "kde4"
    assert_response :success
    assert_tag :tag => "project", :attributes => { :name => "kde4" }
  end
  

  # FIXME: only works with dummy backend
  #def test_get_package_filelist
  #  prepare_request_with_user @request, "tom", "thunder"
  #  get :index_package, :project => "kde4", :package => "kdelibs"
  #  assert_response :success
  #  assert_tag :tag => "directory", :child => { :tag => "entry" }
  #  assert_tag :tag => "directory",
  #    :children => { :count => 3, :only => { :tag => "entry" } }
  #end
  
  def test_get_package_meta
    prepare_request_with_user @request, "tom", "thunder"
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "kdelibs" }
  end
  
  #invalid user should always be rejected
  def test_invalid_user
    prepare_request_with_user @request, "king123", "sunflower"
    get :project_meta, :project => "kde4" 
    assert_response 401
  end
  
  #invalid user should always be rejected  
  def test_invalid_credentials
    prepare_request_with_user @request, "king", "sunflower123"
    get :project_meta, :project => "kde4" 
    assert_response( 401, "--> Invalid pw did not throw Exception")
  end
  
  
  def test_valid_user
    prepare_request_with_user @request, "tom", "thunder"
    get :project_meta, :project => "kde4" 
    assert_response :success
  end
  
  
  
  def test_put_project_meta_with_invalid_permissions
    prepare_request_with_user @request, "tom", "thunder"
    # The user is valid, but has weak permissions
    
    # Get meta file
    get :project_meta, :project => "kde4" 
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :project_meta, :project => "kde4"
    assert_response 403
    
  end
  
  
  def test_put_project_meta
    prepare_request_with_user @request, "king", "sunflower"
    do_change_project_meta_test
    prepare_request_with_user @request, "fred", "geröllheimer"
    do_change_project_meta_test
  end
  

  def do_change_project_meta_test
   # Get meta file  
    get :project_meta, :project => "kde4"
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :project_meta, :project => "kde4"
    assert_response :success
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that it is the changed data
    get :project_meta, :project => "kde4"
    doc = REXML::Document.new( @response.body )
    d = doc.elements["//description"]
    assert_equal new_desc, d.text
  
  end
  private :do_change_project_meta_test
  
  
  
  def test_create_project_meta
    do_create_project_meta_test("king", "sunflower")
  end
  
  
  def do_create_project_meta_test (name, pw)
    prepare_request_with_user(@request, name, pw)
    # Get meta file  
    get :project_meta, :project => "kde4"
    assert_response :success

    xml = @response.body
    doc = REXML::Document.new( xml )
    # change name to kde5: 
    d = doc.elements["/project"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kde5' ) 
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :project_meta, :project => "kde5"
    assert_response(:success, message="--> #{name} was not allowed to create a project")
    assert_tag( :tag => "status", :attributes => { :code => "ok" })

    # Get data again and check that the maintainer was added
    get :project_meta, :project => "kde5"
    assert_response :success
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["/project"]
    assert_equal(d.attribute('name').value(), 'kde5', message="Project name was not set to kde5")
    d = newdoc.elements["//person[@role='maintainer' and @userid='#{name}']"]
    assert_not_nil(d, message="--> Creator was not added automatically as project-maintainer")  
    
     
  end
  private :do_create_project_meta_test
  
  
  
  
  def test_put_invalid_project_meta
    prepare_request_with_user @request, "fred", "geröllheimer"

   # Get meta file  
    get :project_meta, :project => "kde4"
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    @request.env['RAW_POST_DATA'] = doc.to_s + "</xml>"
    put :project_meta, :project => "kde4"
    assert_response 500

    prepare_request_with_user @request, "king", "sunflower"
    # write to illegal location: 
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :project_meta, :project => "../source/bang"
    assert_response( 403, "--> Was able to create project at illegal path")
    put :project_meta
    assert_response( 403, "--> Was able to create project at illegal path")
    put :project_meta, :project => "."
    assert_response( 403, "--> Was able to create project at illegal path")
    
    #must not create a project with different pathname and name in _meta.xml:
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :project_meta, :project => "kde5"
    assert_response( 403, "--> Was able to create project with different project-name in _meta.xml")    
    
    #TODO: referenced repository names must exist
    
    
    #verify data is unchanged: 
    get :project_meta, :project => "kde4" 
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end
  
  
  
  
  def test_put_package_meta_with_invalid_permissions
    prepare_request_with_user @request, "tom", "thunder"
    # The user is valid, but has weak permissions
    
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response 403
    
    #verify data is unchanged: 
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new(( @response.body )).to_s)    
  end
  
  

  def do_change_package_meta_test
   # Get meta file  
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = "Changed description"
    doc = REXML::Document.new( xml )
    d = doc.elements["//description"]
    d.text = new_desc

    # Write changed data back
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response(:success, "--> Was not able to update kdelibs _meta")   
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    # Get data again and check that it is the changed data
    get :package_meta, :project => "kde4", :package => "kdelibs"
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["//description"]
    assert_equal new_desc, d.text
    assert_equal doc.to_s, newdoc.to_s
  end
  private :do_change_package_meta_test



  # admins, project-maintainer and package maintainer can edit package data
  def test_put_package_meta
      prepare_request_with_user @request, "king", "sunflower"
      do_change_package_meta_test
      prepare_request_with_user @request, "fred", "geröllheimer"
      do_change_package_meta_test
      prepare_request_with_user @request, "fredlibs", "geröllheimer"
      do_change_package_meta_test
  end



  def create_package_meta
    # user without any special roles
    prepare_request_with_user @request, "tom", "thunder"
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success
    #change name to kdelibs2
    xml = @response.body
    doc = REXML::Document.new( xml )
    d = doc.elements["/package"]
    d.delete_attribute( 'name' )   
    d.add_attribute( 'name', 'kdelibs2' ) 
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :package_meta, :project => "kde4", :package => "kdelibs2"
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )
    
    # Get data again and check that the maintainer was added
    get :package_meta, :project => "kde4", :package => "kdelibs2"
    assert_response :success
    newdoc = REXML::Document.new( @response.body )
    d = newdoc.elements["/package"]
    assert_equal(d.attribute('name').value(), 'kdelibs2', message="Project name was not set to kdelibs2")
    d = newdoc.elements["//person[@role='maintainer' and @userid='#{tom}']"]
    assert_not_nil(d, message="--> Creator was not added automatically as package-maintainer")  
  end
  private :create_package_meta


  def test_put_invalid_package_meta
    prepare_request_with_user @request, "fredlibs", "geröllheimer"
   # Get meta file  
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new( xml )
    doc = REXML::Document.new( xml )
    # Write corrupt data back
    @request.env['RAW_POST_DATA'] = doc.to_s + "</xml>"
    put :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response 500

    prepare_request_with_user @request, "king", "sunflower"
    # write to illegal location: 
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :package_meta, :project => "kde4", :package => "../bang"
    assert_response( 404, "--> Was able to create package at illegal path")
    put :package_meta, :project => "kde4"
    assert_response( 403, "--> Was able to create package at illegal path")
    put :package_meta, :project => "kde4", :package => "."
    assert_response( 403, "--> Was able to create package at illegal path")
    
    #must not create a package with different pathname and name in _meta.xml:
    @request.env['RAW_POST_DATA'] = doc.to_s
    put :package_meta, :project => "kde4", :package => "kdelibs2000"
    assert_response( 403, "--> Was able to create package with different project-name in _meta.xml")     
    
    #verify data is unchanged: 
    get :package_meta, :project => "kde4", :package => "kdelibs"
    assert_response :success
    assert_equal( olddoc.to_s, REXML::Document.new( ( @response.body )).to_s)
  end



  def test_read_file
    get :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff"
    assert_response :success
    assert_equal( @response.body.to_s, "argl\n" )
    
    get :file, :project => "kde4", :package => "kdelibs", :file => "BLUB"
    #STDERR.puts(@response.body)
    assert_response 404
    assert_tag( :tag => "error" )
    
    get :file, :project => "kde4", :package => "kdelibs", :file => "../kdebase/_meta"
    #STDERR.puts(@response.body)
    assert_response( 404, "Was able to read file outside of package scope" )
    assert_tag( :tag => "error" )
    
  end
  


  def add_file_to_package
    teststring = "&;" 
    @request.env['RAW_POST_DATA'] = teststring
    put :file, :project => "kde4", :package => "kdelibs", :file => "testfile"
    assert_response :success
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )
  
    get :file, :project => "kde4", :package => "kdelibs", :file => "testfile"
    assert_response :success
    assert_equal( @response.body.to_s, teststring )
  end
  private :add_file_to_package
  
  
  
  
  def test_add_file_to_package
    prepare_request_with_user @request, "fredlibs", "geröllheimer"
    add_file_to_package
    prepare_request_with_user @request, "fred", "geröllheimer"
    add_file_to_package
    prepare_request_with_user @request, "king", "sunflower"
    add_file_to_package
  
    # write without permission: 
    prepare_request_with_user @request, "tom", "thunder"
    get :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff"
    assert_response :success
    origstring = @response.body.to_s
    teststring = "&;"
    @request.env['RAW_POST_DATA'] = teststring
    put :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff"
    assert_response( 403, message="Was able to write a package file without permission" )
    assert_tag( :tag => "error" )
    
    # check that content is unchanged: 
    get :file, :project => "kde4", :package => "kdelibs", :file => "my_patch.diff"
    assert_response :success
    assert_equal( @response.body.to_s, origstring, message="Package file was changed without permissions" )
  end
  
  

  def teardown  
    # restore the XML test files
    restore_source_test_data
  end
  
end
