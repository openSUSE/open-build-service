require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'trigger_controller'

class TriggerControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_rebuild_via_token
    post '/person/tom/token?cmd=create'
    assert_response 401

    login_Iggy
    post '/person/Iggy/token?cmd=create&operation=rebuild'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    rebuild_global_token = doc.elements['//data'].text
    rebuild_global_id = doc.elements['//data[@name="id"]'].text
    assert_equal 24, rebuild_global_token.length

    login_tom
    put '/source/home:tom/test/_meta', params: "<package project='home:tom' name='test'> <title /> <description /> </package>"
    assert_response :success

    post '/person/tom/token?cmd=create&project=home:tom&package=test&operation=rebuild'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    rebuild_token = doc.elements['//data'].text
    rebuild_id = doc.elements['//data[@name="id"]'].text
    assert_equal 24, rebuild_token.length

    post '/person/tom/token?cmd=create&project=home:tom&package=test'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    service_token = doc.elements['//data'].text
    service_id = doc.elements['//data[@name="id"]'].text

    # ANONYMOUS
    reset_auth
    post '/trigger/runservice'
    assert_response 403
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_token' }
    assert_match(/No valid token found/, @response.body)

    # with wrong token
    post '/trigger/runservice', headers: { 'Authorization' => 'Token wrong' }
    assert_response 404
    assert_xml_tag tag: 'status', attributes: { code: 'not_found' }

    # with right token
    post '/trigger/runservice', headers: { 'Authorization' => "Token #{service_token}" }
    assert_response 404
    assert_match(/no source service defined/, @response.body) # request reached backend

    # wrong operation
    post '/trigger/release', headers: { 'Authorization' => "Token #{service_token}" }
    assert_response 403
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_token' }
    assert_match(/Invalid token found/, @response.body)

    # wrong package
    post '/trigger/rebuild?project="home:Iggy"&package="TestPack"', headers: { 'Authorization' => "Token #{rebuild_token}" }
    assert_response 400
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_parameter' }

    # entire project rebuild (using upper main route)
    post '/trigger?project=home:Iggy', headers: { 'Authorization' => "Token #{rebuild_global_token}" }
    assert_response :success

    # reset and drop stuff as tom
    login_tom
    get '/person/tom/token'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { project: 'home:tom', package: 'test', kind: 'rebuild' }
    doc = REXML::Document.new(@response.body)
    id = doc.elements['//entry'].attributes['id']
    assert_not_nil id
    assert_not_nil doc.elements['//entry'].attributes['string']
    delete "/person/tom/token/#{service_id}"
    assert_response :success
    delete "/person/tom/token/#{rebuild_id}"
    assert_response :success

    # cleanup
    delete '/source/home:tom/test'
    assert_response :success

    login_Iggy
    delete "/person/Iggy/token/#{rebuild_global_id}"
    assert_response :success
  end
end
