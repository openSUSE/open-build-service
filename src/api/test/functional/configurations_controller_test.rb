require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ConfigurationsControllerTest < ActionController::IntegrationTest
  def setup
    prepare_request_valid_user
  end

  def test_show_and_update_configuration
    get '/configuration'
    assert_response :success
    config = @response.body
    put '/configuration?title=%22openSUSE%20Build%20Service%22&description=%22Long%20description%22', config
    assert_response 403 # Normal users can't change site-wide configuration
    prepare_request_with_user 'king', 'sunflower' # User with admin rights
    put '/configuration?title=%22openSUSE%20Build%20Service%22&description=%22Long%20description%22', config
    assert_response :success
  end
end
