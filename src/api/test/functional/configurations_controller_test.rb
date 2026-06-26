require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    prepare_request_valid_user
  end

  def test_show_and_update_configuration
    login_tom
    get '/public/configuration.json' # is done by webui from OBS 2.4
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal json['title'], 'Open Build Service' # got json
    get '/public/configuration.xml'
    assert_response :success
    assert_xml_tag tag: 'configuration' # is xml
    get '/public/configuration'
    assert_response :success
    assert_xml_tag tag: 'configuration' # is xml
    get '/configuration' # default
    assert_response :success
    config = @response.body
    put '/configuration', params: config
    assert_response :forbidden # Normal users can't change site-wide configuration

    login_king # User with admin rights
    # webui is using this way to store data
    put '/configuration?title=openSUSE&description=blah_fasel&name=obsname'
    assert_response :success
    # webui is using this way to set architectures
    put '/configuration?arch[]=ppc&arch[]=s390x'
    assert_response :success
    get '/configuration.xml'
    assert_response :success
    assert_xml_tag tag: 'title', content: 'openSUSE'
    assert_xml_tag tag: 'description', content: 'blah_fasel'
    assert_xml_tag tag: 'name', content: 'obsname'
    assert_xml_tag tag: 'admin_email', content: 'obs-email@opensuse.org'
    assert_xml_tag parent: { tag: 'schedulers' },
                   tag: 'arch', content: 'ppc'
    assert_xml_tag parent: { tag: 'schedulers' },
                   tag: 'arch', content: 's390x'
    assert_no_xml_tag parent: { tag: 'schedulers' },
                      tag: 'arch', content: 'i586'

    # overwriting options.yml is not allowed
    ::Configuration::OPTIONS_YML[:registration] = 'allow'
    put '/configuration?registration=deny'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'no_permission_to_change' }
    ::Configuration::OPTIONS_YML[:registration] = 'deny'
    put '/configuration?registration=deny'
    assert_response :success
    ::Configuration::OPTIONS_YML[:registration] = nil

    # reset
    put '/configuration', params: config
    assert_response :success

    login_tom
    get '/configuration.xml'
    assert_response :success
    assert_xml_tag tag: 'title', content: 'Open Build Service'
    assert_xml_tag tag: 'name', content: 'obstest'
    assert_xml_tag parent: { tag: 'schedulers' },
                   tag: 'arch', content: 'i586'
    assert_no_xml_tag parent: { tag: 'schedulers' },
                      tag: 'arch', content: 's390x'
  end
end
