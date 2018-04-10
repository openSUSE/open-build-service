# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'time'

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_latest_added
    login_adrian
    get url_for(controller: :source, action: :show_package_meta, project: 'HiddenProject', package: 'test_latest_added')
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: 'HiddenProject', package: 'test_latest_added'),
        params: '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    get url_for(controller: :statistics, action: :latest_added)
    assert_response :success
    assert_xml_tag tag: 'latest_added', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: { name: 'test_latest_added' }

    login_tom
    get url_for(controller: :statistics, action: :latest_added)
    assert_response :success
    assert_xml_tag tag: 'latest_added', child: { tag: 'project' }
    assert_xml_tag tag: 'project', attributes: {
      name: 'home:adrian'
    }

    login_fred
    get url_for(controller: :source, action: :show_package_meta, project: 'kde4', package: 'test_latest_added1')
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: 'kde4', package: 'test_latest_added1'),
        params: '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    get url_for(controller: :statistics, action: :latest_added)
    assert_response :success
    assert_xml_tag tag: 'latest_added', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: { name: 'test_latest_added1' }

    login_king
    delete '/source/kde4/test_latest_added1'
    assert_response :success
    delete '/source/HiddenProject/test_latest_added'
    assert_response :success
  end

  def test_latest_updated
    login_adrian
    get url_for(controller: :source, action: :show_package_meta, project: 'HiddenProject', package: 'test_latest_added')
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: 'HiddenProject', package: 'test_latest_added'),
        params: '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    get url_for(controller: :statistics, action: :latest_updated)
    assert_response :success
    assert_xml_tag tag: 'latest_updated', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: { name: 'test_latest_added' }

    login_tom
    get url_for(controller: :statistics, action: :latest_updated)
    assert_response :success
    assert_xml_tag tag: 'latest_updated', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: {
      name: 'Pack3'
    }

    login_fred
    get url_for(controller: :source, action: :show_package_meta, project: 'kde4', package: 'test_latest_added1')
    assert_response 404
    put url_for(controller: :source, action: :update_package_meta, project: 'kde4', package: 'test_latest_added1'),
        params: '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
    assert_response 200
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    get url_for(controller: :statistics, action: :latest_updated)
    assert_response :success
    assert_xml_tag tag: 'latest_updated', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: { name: 'test_latest_added1' }

    login_king
    delete '/source/kde4/test_latest_added1'
    assert_response :success
    delete '/source/HiddenProject/test_latest_added'
    assert_response :success
  end

  def test_timestamp_calls
    login_adrian
    get url_for(controller: :statistics, action: :added_timestamp, project: 'HiddenProject', package: 'pack')
    assert_response 200

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject', package: 'pack')
    assert_response 200

    get url_for(controller: :statistics, action: :added_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response 200

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response 200

    login_fred
    get url_for(controller: :statistics, action: :added_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response 200

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response 200

    get url_for(controller: :statistics, action: :added_timestamp, project: 'HiddenProject', package: 'not_existing')
    assert_response 404

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject', package: 'not_existing')
    assert_response 404

    get url_for(controller: :statistics, action: :added_timestamp, project: 'HiddenProject')
    assert_response 404

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject')
    assert_response 404
  end

  def test_rating_and_activity
    login_adrian
    get url_for(controller: :statistics, action: :rating, project: 'kde4', package: 'kdelibs')
    assert_response :success

    get url_for(controller: :statistics, action: :rating, project: 'kde4')
    assert_response :success

    get url_for(controller: :statistics, action: :rating, project: 'HiddenProject', package: 'NOT_EXISTING')
    assert_response 404

    get url_for(controller: :statistics, action: :rating, project: 'HiddenProject', package: nil)
    assert_response :success

    get url_for(controller: :statistics, action: :activity, project: 'kde4', package: 'kdelibs')
    assert_response :success

    get url_for(controller: :statistics, action: :activity, project: 'kde4', package: nil)
    assert_response :success

    get url_for(controller: :statistics, action: :activity, project: 'HiddenProject', package: 'pack')
    assert_response :success

    get url_for(controller: :statistics, action: :activity, project: 'HiddenProject', package: nil)
    assert_response :success

    # no access to HiddenProject
    login_fred
    get url_for(controller: :statistics, action: :rating, project: 'kde4', package: 'kdelibs')
    assert_response :success

    get url_for(controller: :statistics, action: :rating, project: 'HiddenProject', package: nil)
    assert_response 404

    get url_for(controller: :statistics, action: :rating, project: 'HiddenProject', package: 'NOT_EXISTING')
    assert_response 404

    get url_for(controller: :statistics, action: :activity, project: 'kde4', package: 'kdelibs')
    assert_response :success
  end

  def test_most_active
    login_tom
    # get most active packages
    get url_for(controller: :statistics, action: :most_active_packages, limit: 0)
    assert_response :success

    assert_xml_tag tag: 'most_active', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: {
      name:    'kdelibs',
      project: 'kde4'
    }
    assert_no_xml_tag tag: 'package', attributes: { project: 'HiddenProject' }

    # get most active projects
    get url_for(controller: :statistics, action: :most_active_projects, limit: 0)
    assert_response :success
    assert_xml_tag tag: 'most_active', child: { tag: 'project' }
    assert_xml_tag tag: 'project', attributes: {
      name:     'kde4',
      packages: 2
    }
    assert_no_xml_tag tag: 'project', attributes: { name: 'HiddenProject' }

    # redo as user, seeing the hidden project
    prepare_request_with_user 'hidden_homer', 'buildservice'
    # get most active packages
    get url_for(controller: :statistics, action: :most_active_packages, limit: 0)
    assert_response :success

    assert_xml_tag tag: 'most_active', child: { tag: 'package' }
    assert_xml_tag tag: 'package', attributes: { project: 'HiddenProject' }

    # get most active projects
    get url_for(controller: :statistics, action: :most_active_projects, limit: 0)
    assert_response :success
    assert_xml_tag tag: 'most_active', child: { tag: 'project' }
    assert_xml_tag tag: 'project', attributes: { name: 'HiddenProject' }
  end

  # FIXME: works, but does not do anything usefull since 2.0 anymore
  #        we need a working rating mechanism, but this one is too simple.
  def test_highest_rated
    login_tom
    get url_for(controller: :statistics, action: :highest_rated)
    assert_response :success
    # assert_xml_tag :tag => 'collection', :child => { :tag => 'xxxxx' }
    # assert_xml_tag :tag => 'package', :attributes => {
    #  :name => "kdelibs",
    #  :xxx => "xxx",
    # }
  end

  def test_active_request_creators
    get url_for(action: :active_request_creators, controller: :statistics, project: 'kde4')
    assert_response 401

    login_tom
    get url_for(action: :active_request_creators, controller: :statistics, project: 'kde4')
    assert_response :success
    assert_xml_tag tag: 'creator', attributes: { login: 'tom', email: 'tschmidt@example.com', count: '1' }

    get url_for(action: :active_request_creators, controller: :statistics, project: 'HiddenProject')
    assert_response 404
  end
end
