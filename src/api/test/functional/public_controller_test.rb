require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'public_controller'

class PublicControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_index
    get '/public'
    assert_response :moved_permanently
  end

  def test_about
    get '/public/about'
    assert_response :success
  end

  def test_basic_read_tests
    get '/public/source/home:Iggy'
    assert_response :success
    get '/public/source/home:Iggy/_meta'
    assert_response :success
    get '/public/source/home:Iggy/_config'
    assert_response :success
    get '/public/source/home:Iggy/TestPack'
    assert_response :success
    get '/public/source/home:Iggy/TestPack/_meta'
    assert_response :success

    # osc repos
    get '/public/configuration'
    assert_response :success
    get '/public/configuration.xml'
    assert_response :success

    get '/public/source' # no such action
    assert_response :not_found

    get '/public/source/DoesNotExist/_meta'
    assert_response :not_found
    get '/public/source/home:Iggy/DoesNotExist/_meta'
    assert_response :not_found

    get '/public/build/home:Iggy/10.2/i586/TestPack'
    assert_response :success

    get '/public/request/1000'
    assert_response :success
    assert_xml_tag tag: 'request', attributes: { id: '1000' }

    get '/public/request/98766123'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'not_found' }

    # remote interconnect from scheduler for product building
    get '/public/build/home:Iggy/10.2/i586'
    assert_response :success

    # hidden project access
    get '/public/source/HiddenProject'
    assert_response :not_found
    get '/public/source/HiddenProject/_config'
    assert_response :not_found
    get '/public/source/HiddenProject/_meta'
    assert_response :not_found
    get '/public/source/HiddenProject/pack'
    assert_response :not_found
    get '/public/source/HiddenProject/pack/_meta'
    assert_response :not_found
    get '/public/source/HiddenProject/pack/my_file'
    assert_response :not_found
  end

  def test_lastevents
    # very old route
    get '/lastevents'
    assert_response :success
    # old method
    get '/public/lastevents'
    assert_response :success
    # new method (OBS 2.3)
    post '/public/lastevents'
    assert_response :success
    # new method (OBS 2.3) using credentials
    login_tom
    post '/lastevents'
    assert_response :success
  end

  def test_distributions
    get '/public/distributions'
    assert_response :success
  end

  def test_get_files
    get '/public/source/home:Iggy/TestPack/myfile'
    assert_response :success
    assert_match 'DummyContent', @response.body

    get '/public/source/home:Iggy/TestPack/myfile2'
    assert_response :not_found
    assert_match(/myfile2: no such file/, @response.body)

    # access to package build area
    get '/public/build/home:Iggy/10.2/i586/TestPack'
    assert :success
    get '/public/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm'
    assert :success

    # access to :full repo
    get '/public/build/home:Iggy/10.2/i586/_repository'
    assert :success
    get '/public/build/home:Iggy/10.2/i586/_repository/package.rpm'
    assert :success
    # FIXME: validate rpm

    get '/public/build/home:Iggy/10.2/i586/TestPack/doesnotexist'
    assert_response :not_found
    # FIXME: do a working getbinary call
  end

  def test_binaries
    run_publisher

    # This URL is used by Frank Karlitschek's kde/gnome/qt-apps.org sites
    get '/public/binary_packages/home:Iggy/TestPack'
    assert_response :success
    assert_xml_tag tag: 'package'
    assert_xml_tag tag: 'list', attributes: { distribution: '1' }
    assert_xml_tag tag: 'repository', attributes: { url: 'http://example.com/download/home:/Iggy/10.2/home:Iggy.repo' }
    assert_xml_tag tag: 'rpm', attributes: { arch: 'i586',
                                             url: 'http://example.com/download/home:/Iggy/10.2/i586/package-1.0-1.i586.rpm' }

    # we can list the binaries, but not download to avoid direct links
    get '/public/build/home:Iggy/10.2/i586/TestPack'
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    get '/public/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm'
    assert_response :ok

    get '/public/build/home:Iggy/10.2/i586/TestPack/not-existent.rpm'
    assert_response :not_found
  end
end
