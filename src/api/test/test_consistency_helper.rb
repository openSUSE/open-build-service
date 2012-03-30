require File.expand_path(File.dirname(__FILE__) + "/..") + "/test/test_helper"
require 'source_controller'

#
# Add all kind of data consistency checks here. It runs before and after all functional tests
# to detect any kind of data corruption due to some other code
#

def resubmit_all_fixtures
  # this just reads and writes again the meta data. 1st run the fixtures and on 2nd all left
  # overs from other other tests
  prepare_request_with_user "king", "sunflower"
  # projects
  get "/source"
  assert_response :success
  node = ActiveXML::XMLNode.new(@response.body)
  node.each_entry do |e|
    get "/source/#{e.name}/_meta"
    assert_response :success
    r = @response.body
    # FIXME: add some more validation checks here
    put "/source/#{e.name}/_meta", r.dup
    assert_response :success
    get "/source/#{e.name}/_meta"
    assert_response :success
    assert_not_nil r
    assert_equal r, @response.body
  
    # packages
    get "/source/#{e.name}"
    assert_response :success
    packages = ActiveXML::XMLNode.new(@response.body)
    packages.each_entry do |p|
      get "/source/#{e.name}/#{p.name}/_meta"
      assert_response :success
      r = @response.body
      # FIXME: add some more validation checks here
      put "/source/#{e.name}/#{p.name}/_meta", r.dup
      assert_response :success
      get "/source/#{e.name}/#{p.name}/_meta"
      assert_response :success
      assert_not_nil r
      assert_equal r, @response.body
    end
  end
end
