require File.dirname(__FILE__) + '/../test_helper'

class BuildControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_valid_user

    @controller = BuildController.new
    @controller.start_test_backend

    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)

  end

  def test_index
    get "/build"
    assert_response :success
    assert_match /entry name="home:tscholz"/, @response.body
  end

  def test_buildinfo
    # just testing routing
    get "/build/buildinfo"
    assert_response 404
    assert_match /project 'buildinfo' does not exist/, @response.body

    get "/build/home:tscholz/10.2/i586/TestPack/_buildinfo"
    # we can't test this without running schedulers
    #assert_response :success
  end

  def test_package_index
    get "/build/home:tscholz/10.2/i586/TestPack"
    assert_response :success
    assert_tag( :tag => "binarylist" ) 
  end

  def test_logfile
    get "/build/home:tscholz/10.2/i586/TestPack/_log"
    # no workers, no logfile
    assert_match /no logfile/, @response.body

    get "/build/home:tscholz/10.2/i586/notthere/_log"
    assert_response 404
    assert_match /package 'notthere' does not exist/, @response.body

  end

end
