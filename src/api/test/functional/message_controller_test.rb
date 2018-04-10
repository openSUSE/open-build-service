# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class MessageControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    prepare_request_valid_user
  end

  def test_index
    get '/message'
    assert_response :success

    get '/message/1'
    assert_response 404

    get '/message?project=home:Iggy'
    assert_response :success

    get '/message?project=home:Iggy&package=TestPack'
    assert_response :success
    assert_xml_tag(tag: 'messages')

    post '/message/1', params: '<hallo/>'
    assert_response 404

    put '/message', params: '<hallo/>'
    assert_response 400
    assert_match(/validation error/, @response.body)

    put '/message', params: '<message severity="1" send_mail="true" private="true">sample message...</message>'
    assert_response 400
    assert_match(/must give either project or package/, @response.body)

    put '/message?package=TestPack', params: '<message severity="1" send_mail="true" private="true">sample message...</message>'
    assert_response 400
    assert_match(/must give either project or package/, @response.body)

    put '/message?project=home:Iggy', params: '<message severity="1" send_mail="true" private="true">sample message...</message>'
    assert_response 403 # so close!

    put '/message?project=home:tom', params: '<message severity="1" send_mail="true" private="true">sample message...</message>'
    assert_response 200

    get '/message'
    assert_response :success
    ret = ActiveXML::Node.new @response.body
    ret.each('message') do |m|
      msg_id = m.value('msg_id')
      # test show too
      get "/message/#{msg_id}"
      assert_response :success

      delete "/message/#{msg_id}"
      assert_response :success

      # should fail a second time
      delete "/message/#{msg_id}"
      assert_response 404
      assert_match %r{Couldn't find Message with}, @response.body
    end

    login_Iggy
    put '/message?project=home:Iggy&package=TestPack', params: '<message severity="1" send_mail="true" private="true">sample message...</message>'
    assert_response 200

    get '/message'
    assert_response :success
    ret = ActiveXML::Node.new @response.body
    ret.each('message') do |m|
      delete "/message/#{m.value('msg_id')}"
      assert_response :success
    end
  end
end
