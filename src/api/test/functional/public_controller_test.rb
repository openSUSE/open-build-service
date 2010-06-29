require File.dirname(__FILE__) + '/../test_helper'

class PublicControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_valid_user
    @controller = PublicController.new
    @controller.start_test_backend

    Suse::Backend.delete( '/source/home:tscholz' )
    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)
  end
 
  def test_index
    get "/public"
    assert_response 302
  end

  def test_build
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

  def test_binaries
    get "/public/binary_packages/home:tscholz/TestPack"
    assert_response :success
  end

  def test_binaries
    get "/public/source/home:tscholz/TestPack/myfile"
    assert_response 404
    assert_match /myfile: no such file/, @response.body
  end

end
