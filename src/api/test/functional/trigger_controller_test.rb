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
    assert_xml_tag tag: 'status', attributes: { code: 'permission_denied' }
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

  def test_branch_via_token
    login_tom
    put '/source/home:tom/test/_meta', params: "<package project='home:tom' name='test'> <title /> <description /> </package>"
    assert_response :success

    post '/person/tom/token?cmd=create&project=home:tom&package=test&operation=branch'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    token = doc.elements['//data'].text
    assert_equal 24, token.length

    # ANONYMOUS
    reset_auth
    post '/trigger/branch'
    assert_response 403
    assert_xml_tag tag: 'status', attributes: { code: 'permission_denied' }
    assert_match(/No valid token found/, @response.body)

    # call with a gitlab payload. based on documentation example
    payload = '
{
  "object_kind": "merge_request",
  "user": {
    "id": 1,
    "name": "Administrator",
    "username": "root",
    "avatar_url": "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon",
    "email": "admin@example.com"
  },
  "project": {
    "id": 1,
    "name":"Gitlab Test",
    "description":"Aut reprehenderit ut est.",
    "web_url":"http://example.com/gitlabhq/gitlab-test",
    "avatar_url":null,
    "git_ssh_url":"git@example.com:gitlabhq/gitlab-test.git",
    "git_http_url":"http://example.com/gitlabhq/gitlab-test.git",
    "namespace":"GitlabHQ",
    "visibility_level":20,
    "path_with_namespace":"gitlabhq/gitlab-test",
    "default_branch":"master",
    "homepage":"http://example.com/gitlabhq/gitlab-test",
    "url":"http://example.com/gitlabhq/gitlab-test.git",
    "ssh_url":"git@example.com:gitlabhq/gitlab-test.git",
    "http_url":"http://example.com/gitlabhq/gitlab-test.git"
  },
  "repository": {
    "name": "Gitlab Test",
    "url": "http://example.com/gitlabhq/gitlab-test.git",
    "description": "Aut reprehenderit ut est.",
    "homepage": "http://example.com/gitlabhq/gitlab-test"
  },
  "object_attributes": {
    "id": 99,
    "target_branch": "master",
    "source_branch": "ms-viewport",
    "source_project_id": 14,
    "author_id": 51,
    "assignee_id": 6,
    "title": "MS-Viewport",
    "created_at": "2013-12-03T17:23:34Z",
    "updated_at": "2013-12-03T17:23:34Z",
    "milestone_id": null,
    "state": "opened",
    "merge_status": "unchecked",
    "target_project_id": 14,
    "iid": 1,
    "description": "",
    "source": {
      "name":"Awesome Project",
      "description":"Aut reprehenderit ut est.",
      "web_url":"http://example.com/awesome_space/awesome_project",
      "avatar_url":null,
      "git_ssh_url":"git@example.com:awesome_space/awesome_project.git",
      "git_http_url":"http://example.com/awesome_space/awesome_project.git",
      "namespace":"Awesome Space",
      "visibility_level":20,
      "path_with_namespace":"awesome_space/awesome_project",
      "default_branch":"master",
      "homepage":"http://example.com/awesome_space/awesome_project",
      "url":"http://example.com/awesome_space/awesome_project.git",
      "ssh_url":"git@example.com:awesome_space/awesome_project.git",
      "http_url":"http://example.com/awesome_space/awesome_project.git"
    },
    "target": {
      "name":"Awesome Project",
      "description":"Aut reprehenderit ut est.",
      "web_url":"http://example.com/awesome_space/awesome_project",
      "avatar_url":null,
      "git_ssh_url":"git@example.com:awesome_space/awesome_project.git",
      "git_http_url":"http://example.com/awesome_space/awesome_project.git",
      "namespace":"Awesome Space",
      "visibility_level":20,
      "path_with_namespace":"awesome_space/awesome_project",
      "default_branch":"master",
      "homepage":"http://example.com/awesome_space/awesome_project",
      "url":"http://example.com/awesome_space/awesome_project.git",
      "ssh_url":"git@example.com:awesome_space/awesome_project.git",
      "http_url":"http://example.com/awesome_space/awesome_project.git"
    },
    "last_commit": {
      "id": "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "message": "fixed readme",
      "timestamp": "2012-01-03T23:36:29+02:00",
      "url": "http://example.com/awesome_space/awesome_project/commits/da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
      "author": {
        "name": "GitLab dev user",
        "email": "gitlabdev@dv6700.(none)"
      }
    },
    "work_in_progress": false,
    "url": "http://example.com/diaspora/merge_requests/1",
    "action": "open",
    "assignee": {
      "name": "User1",
      "username": "user1",
      "avatar_url": "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=40\u0026d=identicon"
    }
  },
  "labels": [{
    "id": 206,
    "title": "API",
    "color": "#ffffff",
    "project_id": 14,
    "created_at": "2013-12-03T17:15:43Z",
    "updated_at": "2013-12-03T17:15:43Z",
    "template": false,
    "description": "API related issues",
    "type": "ProjectLabel",
    "group_id": 41
  }],
  "changes": {
    "updated_by_id": {
      "previous": null,
      "current": 1
    },
    "updated_at": {
      "previous": "2017-09-15 16:50:55 UTC",
      "current":"2017-09-15 16:52:00 UTC"
    },
    "labels": {
      "previous": [{
        "id": 206,
        "title": "API",
        "color": "#ffffff",
        "project_id": 14,
        "created_at": "2013-12-03T17:15:43Z",
        "updated_at": "2013-12-03T17:15:43Z",
        "template": false,
        "description": "API related issues",
        "type": "ProjectLabel",
        "group_id": 41
      }],
      "current": [{
        "id": 205,
        "title": "Platform",
        "color": "#123123",
        "project_id": 14,
        "created_at": "2013-12-03T17:15:43Z",
        "updated_at": "2013-12-03T17:15:43Z",
        "template": false,
        "description": "Platform related issues",
        "type": "ProjectLabel",
        "group_id": 41
      }]
    }
  }
}'
    post('/trigger/branch', headers: { 'Authorization' => "Token #{token}" }, params: payload)
    # backend output ignored atm :/
    assert_response :success

    login_tom
    get '/source/home:tom:MERGE:home:tom:test:1/test/_branch_request'
    assert_response :success

    # cleanup
    get '/person/tom/token'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { project: 'home:tom', package: 'test', kind: 'branch' }
    delete '/source/home:tom:MERGE:home:tom:test:1'
    assert_response :success
    delete '/source/home:tom/test'
    assert_response :success
    get '/person/tom/token'
    assert_response :success
    assert_no_xml_tag tag: 'entry', attributes: { project: 'home:tom', package: 'test', kind: 'branch' }
  end
end
