require_relative 'test_helper'
require 'source_controller'

#
# code which is supposed to be run at multiple stages during the test suite run
#

def resubmit_all_fixtures
  # this just reads and writes again the meta data. 1st run the fixtures and on 2nd all left
  # overs from other other tests
  prepare_request_with_user('king', 'sunflower')
  # projects
  get '/source'
  assert_response :success
  node = Xmlhash.parse(@response.body)
  node.elements('entry') do |e|
    name = e['name']
    get "/source/#{name}/_meta"
    assert_response :success
    r = @response.body
    User.session = User.find_by_login('king')
    next if Project.find_by_name(name).locked?

    User.session = nil
    # FIXME: add some more validation checks here
    put "/source/#{name}/_meta", params: r.dup
    assert_response :success
    get "/source/#{name}/_meta"
    assert_response :success
    assert_not_nil r
    assert_equal r, @response.body

    # packages
    get "/source/#{name}"
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    packages.elements('entry') do |p|
      get "/source/#{name}/#{p['name']}/_meta"
      assert_response :success
      r = @response.body
      # FIXME: add some more validation checks here
      put "/source/#{name}/#{p['name']}/_meta", params: r.dup
      assert_response :success
      get "/source/#{name}/#{p['name']}/_meta"
      assert_response :success
      assert_not_nil r
      assert_equal r, @response.body, "in #{name}"
    end
  end
end
