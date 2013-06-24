require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    prepare_request_valid_user
  end

  def test_show_and_update_configuration
    reset_auth
    get '/public/configuration' # required for anonymous remote webui access
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    get '/public/configuration'
    assert_response :success
    get '/configuration' # default
    assert_response :success
    config = @response.body
    put '/configuration', config
    assert_response 403 # Normal users can't change site-wide configuration

    prepare_request_with_user 'king', 'sunflower' # User with admin rights
    # webui is using this way to store data
    put '/configuration?title=openSUSE&description=blah_fasel&name=obsname'
    assert_response :success
    # webui is using this way to set architectures
    put '/configuration?arch[]=ppc&arch[]=s390x'
    assert_response :success
    get '/configuration.xml'
    assert_response :success
    assert_xml_tag :tag => "title", :content => "openSUSE"
    assert_xml_tag :tag => "description", :content => "blah_fasel"
    assert_xml_tag :tag => "name", :content => "obsname"
    assert_xml_tag :parent => { :tag => "schedulers" },
                   :tag => "arch", :content => "ppc"
    assert_xml_tag :parent => { :tag => "schedulers" },
                   :tag => "arch", :content => "s390x"
    assert_no_xml_tag :parent => { :tag => "schedulers" },
                   :tag => "arch", :content => "i586"

    # reset
    put '/configuration', config
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    get '/configuration.xml'
    assert_response :success
    assert_xml_tag :tag => "title", :content => "Open Build Service"
    assert_xml_tag :tag => "name", :content => "obstest"
    assert_xml_tag :parent => { :tag => "schedulers" },
                   :tag => "arch", :content => "i586"
    assert_no_xml_tag :parent => { :tag => "schedulers" },
                   :tag => "arch", :content => "s390x"
    get '/configuration'
    assert_response :success
  end
end
