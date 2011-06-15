require File.dirname(__FILE__) + '/../test_helper'

class ConfigurationsControllerTest < ActionController::IntegrationTest
  def setup
    prepare_request_valid_user
  end

  def test_should_show_configuration
    get '/configuration'
    assert_response :success
  end

  def test_should_update_configuration
    put '/configuration', :title => 'openSUSE Build Service', :description => 'Long description'
    assert_response 403 # Normal users can't change site-wide configuration
    prepare_request_with_user 'king', 'sunflower' # User with admin rights
    put '/configuration', :title => 'openSUSE Build Service', :description => 'Long description'
    assert_response 400
  end
end
