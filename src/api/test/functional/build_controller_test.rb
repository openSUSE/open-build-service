require File.dirname(__FILE__) + '/../test_helper'

class BuildControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_valid_user
  end

  def test_index
    get "/build"
    assert_response :success
    assert_match(/entry name="home:Iggy"/, @response.body)
  end

  def test_buildinfo
    # just testing routing
    get "/build/buildinfo"
    assert_response 404
    assert_match(/project 'buildinfo' does not exist/, @response.body)

    get "/build/home:Iggy/10.2/i586/TestPack/_buildinfo"
    # we can't test this without running schedulers
    #assert_response :success
  end

  def test_package_index
    get "/build/home:Iggy/10.2/i586/TestPack"
    assert_response :success
    assert_tag( :tag => "binarylist" ) 
  end

  def test_logfile
    get "/build/home:Iggy/10.2/i586/TestPack/_log"
    assert_response :success

    get "/build/home:Iggy/10.2/i586/notthere/_log"
    assert_response 404
    assert_match(/package 'notthere' does not exist/, @response.body)
  end
  
  def test_result
    get "/build/home:Iggy/_result"
    assert_response :success
    assert_tag :tag => "resultlist", :children =>  { :count => 2 }
  end

  def test_binary_view
    get "/build/home:Iggy/10.2/i586/TestPack/file?view=fileinfo"
    assert_response 404
    assert_match(/file: No such file or directory/, @response.body)

    get "/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm?view=fileinfo"
    assert_response :success
    #FIXME validate xml content
  end

  def test_file
    get "/build/home:Iggy/10.2/i586/TestPack"
    assert_response 200
    get "/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm"
    assert_response 200
    get "/build/home:Iggy/10.2/i586/TestPack/NOT_EXISTING"
    assert_response 404
    assert_match(/NOT_EXISTING: No such file or directory/, @response.body)
  end

  def test_project_index
    get "/build/home:Iggy"
    assert_response :success
    assert_tag :tag => "directory", :children =>  { :count => 1 }

    put "/build/home:Iggy", :cmd => 'say_hallo'
    assert_response 403
    assert_match(/No permission to execute command on project/, @response.body)

    post "/build/home:Iggy", :cmd => 'say_hallo'
    assert_response 400
    assert_match(/unsupported POST command/, @response.body)

    prepare_request_with_user "Iggy", "asdfasdf" 
    post "/build/home:Iggy"
    assert_response 400
    post "/build/home:Iggy?cmd=say_hallo"
    assert_response 400
    post "/build/home:NotExisting?cmd=wipe"
    assert_response 404
    assert_match(/Project does not exist/, @response.body)
    post "/build/home:Iggy?cmd=wipe&package=DoesNotExist"
    assert_response 404
    assert_match(/unknown package: DoesNotExist/, @response.body)
  
    post "/build/home:Iggy?cmd=wipe"
    assert_response :success
    post "/build/home:Iggy?cmd=wipe&package=TestPack"
    assert_response :success

    prepare_request_with_user "adrian", "so_alone" 
    post "/build/home:Iggy?cmd=wipe"
    assert_response 403
    assert_match(/No permission to execute command on project/, @response.body)
    post "/build/home:Iggy?cmd=wipe&package=TestPack"
    assert_response 403
    assert_match(/No permission to execute command on package/, @response.body)
  end
  
  def test_remoteinstance
    # check that we handle this correctly - the remoteinstance is only in the database
    get "/build/RemoteInstance:BaseDistro/_result?view=summary"
    assert_response 404
  end
end
