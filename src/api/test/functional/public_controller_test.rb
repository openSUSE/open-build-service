require File.dirname(__FILE__) + '/../test_helper'
require 'public_controller'

class PublicControllerTest < ActionController::IntegrationTest 
  fixtures :all
  
  def setup
    @controller = PublicController.new
    @controller.start_test_backend

    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_prjconf', "DUMMY")
  end
 
  def test_index
    get "/public"
    assert_response 302
  end

  def test_basic_read_tests
    get "/public/source/home:tscholz"
    assert_response :success
    get "/public/source/home:tscholz/_meta"
    assert_response :success
    get "/public/source/home:tscholz/_config"
    assert_response :success
    get "/public/source/home:tscholz/TestPack"
    assert_response :success
    get "/public/source/home:tscholz/TestPack/_meta"
    assert_response :success

    get "/public/source"
    assert_response 403
    get "/public/source/DoesNotExist/_meta"
    assert_response 404
    get "/public/source/home:tscholz/DoesNotExist/_meta"
    assert_response 404

    get "/public/build/home:tscholz/10.2/i586/TestPack"
    assert_response :success
  end

  def test_lastevents
    # old route
    get "/lastevents"
    assert_response :success
    # new route
    get "/public/lastevents"
    assert_response :success
  end

  def test_distributions
    get "/public/distributions"
    assert_response :success
  end

  def test_get_files
    get "/public/source/home:tscholz/TestPack/myfile"
    assert_response 404
    assert_match /myfile: no such file/, @response.body

    get "/public/build/home:tscholz/10.2/i586/TestPack/doesnotexist"
    assert_response 404
    # FIXME: do a working getbinary call
  end

  def test_binaries
    get "/public/binary_packages/home:tscholz/TestPack"
    assert_response :success
    # without binaries, there is little to test here
    assert_tag :tag => 'package'
  end
end
