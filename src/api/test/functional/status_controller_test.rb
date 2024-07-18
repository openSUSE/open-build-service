require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class StatusControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    prepare_request_valid_user
  end

  def test_calculate_workers_by_constraints
    post '/worker'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_parameter' })
    post '/worker?cmd=checkconstraints&project=HiddenProject&package=TestPack&repository=10.2&arch=i586'
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })
    post '/worker?cmd=checkconstraints&project=home:Iggy&package=TestPack&repository=10.2&arch=i586'
    assert_response :success
    assert_select 'directory' do
      assert_select 'entry', name: 'x86_64:build33:1'
    end
    raw_post '/worker?cmd=checkconstraints&project=home:Iggy&package=TestPack&repository=10.2&arch=i586',
             '<constraints></constraints>' # real calculation tests are done in backend test suite
    assert_response :success
    assert_select 'directory' do
      assert_select 'entry', name: 'x86_64:build33:1'
    end
  end

  def test_worker_capability
    get '/worker/x86_64:build33:1'
    assert_response :success
    assert_select 'worker', hostarch: 'x86_64', registerserver: 'http://4.3.2.1:5253', workerid: 'worker:1' do
      assert_select 'sandbox', 'kvm'
    end
  end

  def test_workerstatus
    get '/worker/_status'          # official route since OBS 2.8
    assert_response :success
    assert_xml_tag(tag: 'daemon', attributes: { type: 'publisher', state: 'dead' })
    assert_xml_tag(tag: 'idle', attributes: { workerid: 'worker:1', hostarch: 'x86_64' })

    get '/build/_workerstatus'     # to be dropped FIXME3.0
    assert_response :success
    get '/status/workerstatus'
    assert_response :success
  end

  def test_project_status
    # exists only in the API, should give minimal status
    get '/status/project/home:Iggy'
    assert_response :success
  end
end
