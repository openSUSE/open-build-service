# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class ArchitecturesControllerTest < ActionDispatch::IntegrationTest
  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_index
    # Get all issue trackers
    get '/architectures'
    assert_response 401

    prepare_request_valid_user
    get '/architectures'
    assert_response :success

    assert_xml_tag tag: 'entry', attributes: { name: 'x86_64' }
    assert_xml_tag tag: 'entry', attributes: { name: 'ppc' }
  end

  def test_show
    prepare_request_valid_user
    get '/architectures/i586'
    assert_response :success

    assert_xml_tag tag: 'architecture', attributes: { name: 'i586' }

    get '/architectures/futurearch'
    assert_response 400
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_architecture' }
  end
end
