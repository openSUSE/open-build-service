# encoding: UTF-8

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class BranchPublishFlagTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  @@verbose = false

  def debug(message)
    puts message if @@verbose
  end

  def branch_helper(parent_publish_allowed, expected_publish_allowed)
    if parent_publish_allowed
      # publish is not disabled for Apache
      sprj = 'Apache'
      spkg = 'apache2'
    else
      # publish is disabled for BinaryprotectedProject
      sprj = 'BinaryprotectedProject'
      spkg = 'bdpack'
    end

    tprj = "home:king:branches:#{sprj}"

    debug "branching #{sprj}/#{spkg} into #{tprj}"
    post "/source/#{sprj}/#{spkg}", params: { cmd: :branch, target_project: tprj }
    debug @response.body
    assert_response :success
    if @@verbose
      debug 'here is the branch:'
      get "/source/#{tprj}"
      debug @response.body
    end
    debug "fetching branch's meta:"
    get "/source/#{tprj}/_meta"
    debug @response.body

    if expected_publish_allowed
      # the XML says nothing about whether publishing is enabled, which means
      # it is
      assert_no_xml_tag tag: 'publish'
    else
      # publishing is explicitly disabled
      assert_xml_tag tag: 'publish', child: { tag: 'disable' }
    end

    # get rid of the branch so we can try again
    debug 'deleting branch'
    delete "/source/#{tprj}"
    debug @response.body
    assert_response :success
  end

  def test_branching
    # we use an admin user so we can twiddle the configuration
    login_king

    # by default, OBS expects to have thousands of users, so publishing new
    # branches is disabled to save resources
    branch_helper(true, false)
    branch_helper(false, false)

    # "small team" mode: resources are unconstrained so we might as well
    # publish everything by default
    debug 'allowing publishing for branches'
    put '/configuration?disable_publish_for_branches=off'
    debug @response.body
    assert_response :success
    branch_helper(true, true)
    # ... but if the parent project isn't published, neither is the branch
    branch_helper(false, false)

    # explicitly go back to the default and check that the result is still
    # the same
    debug 'explicitly disallowing publishing for branches'
    put '/configuration?disable_publish_for_branches=on'
    debug @response.body
    assert_response :success
    branch_helper(true, false)
    branch_helper(false, false)
  end
end
