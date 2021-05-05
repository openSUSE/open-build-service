require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class DistributionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_we_survive_remote_instances_timeouts
    login_tom
    stub_request(:get, "http://localhost:#{CONFIG['source_port']}/distributions.xml").to_timeout
    get '/distributions/include_remotes'
    assert_response :success
    # only the one local is included
    assert_xml_tag tag: 'distributions', children: { count: 2 }
  end
end
