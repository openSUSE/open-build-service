require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'time'

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_latest_added
    login_adrian
    get url_for(controller: :source_package_meta, action: :show, project: 'HiddenProject', package: 'test_latest_added')
    assert_response :not_found
    put url_for(controller: :source_package_meta, action: :update, project: 'HiddenProject', package: 'test_latest_added'),
        params: '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
    assert_response :ok
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
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'test_latest_added1')
    assert_response :not_found
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'test_latest_added1'),
        params: '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
    assert_response :ok
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
    get url_for(controller: :source_package_meta, action: :show, project: 'HiddenProject', package: 'test_latest_added')
    assert_response :not_found
    put url_for(controller: :source_package_meta, action: :update, project: 'HiddenProject', package: 'test_latest_added'),
        params: '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
    assert_response :ok
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
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'test_latest_added1')
    assert_response :not_found
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'test_latest_added1'),
        params: '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
    assert_response :ok
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
    assert_response :ok

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject', package: 'pack')
    assert_response :ok

    get url_for(controller: :statistics, action: :added_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response :ok

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response :ok

    login_fred
    get url_for(controller: :statistics, action: :added_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response :ok

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'kde4', package: 'kdelibs')
    assert_response :ok

    get url_for(controller: :statistics, action: :added_timestamp, project: 'HiddenProject', package: 'not_existing')
    assert_response :not_found

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject', package: 'not_existing')
    assert_response :not_found

    get url_for(controller: :statistics, action: :added_timestamp, project: 'HiddenProject')
    assert_response :not_found

    get url_for(controller: :statistics, action: :updated_timestamp, project: 'HiddenProject')
    assert_response :not_found
  end

  def test_activity
    login_adrian
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
      name: 'kdelibs',
      project: 'kde4'
    }
    assert_no_xml_tag tag: 'package', attributes: { project: 'HiddenProject' }

    # get most active projects
    get url_for(controller: :statistics, action: :most_active_projects, limit: 0)
    assert_response :success
    assert_xml_tag tag: 'most_active', child: { tag: 'project' }
    assert_xml_tag tag: 'project', attributes: {
      name: 'kde4',
      packages: 2
    }
    assert_no_xml_tag tag: 'project', attributes: { name: 'HiddenProject' }

    # redo as user, seeing the hidden project
    prepare_request_with_user('hidden_homer', 'buildservice')
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

  def test_active_request_creators
    get url_for(action: :active_request_creators, controller: :statistics, project: 'kde4')
    assert_response :unauthorized

    login_tom
    get url_for(action: :active_request_creators, controller: :statistics, project: 'kde4')
    assert_response :success
    assert_xml_tag tag: 'creator', attributes: { login: 'tom', email: 'tschmidt@example.com', count: '1' }

    get url_for(action: :active_request_creators, controller: :statistics, project: 'HiddenProject')
    assert_response :not_found
  end
end
