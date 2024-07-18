require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class ArchitecturesControllerTest < ActionDispatch::IntegrationTest
  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_index
    # Get all issue trackers
    get '/architectures'
    assert_response :unauthorized

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
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_architecture' }
  end
end
