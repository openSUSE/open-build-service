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

    login_tom
    put '/source/home:tom/test/_meta', params: "<package project='home:tom' name='test'> <title /> <description /> </package>"
    assert_response :success

    post '/person/tom/token?cmd=create&project=home:tom&package=test&operation=rebuild'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    token = doc.elements['//data'].text
    assert_equal 24, token.length

    # ANONYMOUS
    reset_auth
    post '/trigger/rebuild'
    assert_response 403
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_token' }
    assert_match(/No valid token found/, @response.body)

    # with wrong token
    post '/trigger/rebuild', headers: { 'Authorization' => 'Token wrong' }
    assert_response 404
    assert_xml_tag tag: 'status', attributes: { code: 'not_found' }

    # with right token
    post '/trigger/rebuild', headers: { 'Authorization' => "Token #{token}" }
    # backend output ignored atm :/
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
    delete "/person/tom/token/#{id}"
    assert_response :success

    # cleanup
    delete '/source/home:tom/test'
    assert_response :success
  end
end
