require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ConfigurationsControllerTest < ActionController::IntegrationTest
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
    get '/configuration'
    assert_response :success
    put '/configuration', config
    assert_response :success
    # webui is using this way to store data
    put '/configuration?title=openSUSE&description=blah_fasel'
    assert_response :success
    prepare_request_with_user "tom", "thunder"
    get '/configuration.xml'
    assert_response :success
    assert_xml_tag :tag => "title", :content => "openSUSE"
    assert_xml_tag :tag => "description", :content => "blah_fasel"
  end
end
