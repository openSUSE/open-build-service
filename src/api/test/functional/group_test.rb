require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class GroupControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_list_groups
    get '/group'
    assert_response :unauthorized

    prepare_request_valid_user
    get '/group'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group' }
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group_b' }

    get '/group?login=adrian'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group' }

    get '/group?prefix=test'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group' }
  end

  def test_get_group
    get '/group/test_group'
    assert_response :unauthorized

    prepare_request_valid_user
    get '/group/test_group'
    assert_response :success
    assert_xml_tag parent: { tag: 'group' }, tag: 'title', content: 'test_group'
    assert_xml_tag tag: 'person', attributes: { userid: 'adrian' }
    assert_xml_tag parent: { tag: 'person' }, tag: 'person', attributes: { userid: 'adrian' }

    get '/group/does_not_exist'
    assert_response :not_found
  end

  def test_create_modify_and_delete_group
    xml = '<group><title>new_group</title><maintainer userid="Iggy"/><person><person userid="adrian"/></person></group>'
    put '/group/new_group', params: xml
    assert_response :unauthorized

    prepare_request_valid_user
    put '/group/new_group', params: xml
    assert_response :forbidden
    delete '/group/new_group'
    assert_response :not_found
    delete '/group/test_group' # exists
    assert_response :forbidden

    login_king
    get '/group/new_group'
    assert_response :not_found
    delete '/group/new_group'
    assert_response :not_found
    put '/group/test_group', params: xml
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_parameter' }
    assert_xml_tag tag: 'summary', content: 'group name from path and xml mismatch'
    put '/group/NOT_EXISTING_group', params: xml
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_parameter' }
    assert_xml_tag tag: 'summary', content: 'group name from path and xml mismatch'
    put '/group/new_group', params: xml
    assert_response :success

    # add a user
    xml2 = "<group><title>new_group</title> <email>obs@obs.com</email>
              <person><person userid='fred' /></person>
            </group>"
    put '/group/new_group', params: xml2
    assert_response :success
    get '/group/new_group'
    assert_response :success
    assert_xml_tag tag: 'email', content: 'obs@obs.com'

    login_Iggy # not a group maintainer (yet)
    put '/group/new_group', params: xml2
    assert_response :forbidden

    # double save is done by webui, we need to support it. Drop email adress also
    login_king
    xml2 = "<group><title>new_group</title>
              <maintainer userid='Iggy' />
              <person><person userid='fred' /><person userid='fred' /></person>
            </group>"
    put '/group/new_group', params: xml2
    assert_response :success
    get '/group/new_group'
    assert_response :success
    assert_xml_tag tag: 'person', attributes: { userid: 'fred' }
    assert_xml_tag tag: 'maintainer', attributes: { userid: 'Iggy' }
    assert_no_xml_tag tag: 'email'

    # check permissions
    login_adrian
    put '/group/new_group', params: xml2
    assert_response :forbidden
    login_Iggy # group maintainer
    put '/group/new_group', params: xml2
    assert_response :success

    # remove user
    put '/group/new_group', params: xml
    assert_response :success
    get '/group/new_group'
    assert_response :success
    assert_no_xml_tag tag: 'person', attributes: { userid: 'fred' }

    # remove group
    login_king
    delete '/group/new_group'
    assert_response :success
    get '/group/new_group'
    assert_response :not_found
  end

  def test_add_and_remove_users_from_group
    prepare_request_valid_user
    post '/group/test_group', params: { cmd: 'add_user', userid: 'Iggy' }
    assert_response :forbidden
    post '/group/test_group', params: { cmd: 'remove_user', userid: 'Iggy' }
    assert_response :forbidden
    post '/group/test_group', params: { cmd: 'set_email', email: 'obs@obs.de' }
    assert_response :forbidden
    get '/group/test_group'
    assert_response :success
    assert_no_xml_tag tag: 'person', attributes: { userid: 'Iggy' }

    # as admin
    login_king
    post '/group/test_group', params: { cmd: 'add_user', userid: 'Iggy' }
    assert_response :success
    # double add is a dummy operation, but needs to work for webui
    post '/group/test_group', params: { cmd: 'add_user', userid: 'Iggy' }
    assert_response :success
    post '/group/test_group', params: { cmd: 'set_email', email: 'email@me' }
    assert_response :success
    get '/group/test_group'
    assert_response :success
    assert_xml_tag tag: 'person', attributes: { userid: 'Iggy' }
    assert_xml_tag tag: 'email', content: 'email@me'
    post '/group/test_group', params: { cmd: 'remove_user', userid: 'Iggy' }
    assert_response :success
    post '/group/test_group', params: { cmd: 'set_email' }
    assert_response :success
    get '/group/test_group'
    assert_response :success
    assert_no_xml_tag tag: 'person', attributes: { userid: 'Iggy' }
    assert_no_xml_tag tag: 'email'

    # done, back at old state
  end

  def test_list_users_of_group
    get '/group/not_existing_group'
    assert_response :unauthorized

    prepare_request_valid_user
    get '/group/not_existing_group'
    assert_response :not_found
    get '/group/test_group'
    assert_response :success
    assert_xml_tag tag: 'group', child: { tag: 'title' }, content: 'test_group'
    assert_xml_tag tag: 'person', attributes: { userid: 'adrian' }
  end

  def test_groups_of_user
    get '/person/adrian/group'
    assert_response :unauthorized

    prepare_request_valid_user
    # old way, obsolete with OBS 3
    get '/person/adrian/group'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'test_group_b' }

    # new way, standard since OBS 2.3
    get '/group?login=adrian'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'entry', attributes: { name: 'test_group' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'test_group_b' }
  end
end
