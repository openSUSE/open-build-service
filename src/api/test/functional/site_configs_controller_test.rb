require File.dirname(__FILE__) + '/../test_helper'

class SiteConfigsControllerTest < ActionController::IntegrationTest
  def setup
    prepare_request_valid_user
  end

  def test_should_show_site_config
    get '/site_config'
    assert_response :success
  end

  def test_should_get_edit
    get '/site_config/edit'
    assert_response :success
  end

  def test_should_update_site_config
    put '/site_config', :title => 'openSUSE Build Service', :description => 'Long description'
    assert_response 403 # Normal users can't change site-wide configuration
    prepare_request_with_user 'king', 'sunflower' # User with admin rights
    put '/site_config', :title => 'openSUSE Build Service', :description => 'Long description'
    assert_redirected_to site_config_path(assigns(:site_config))
  end
end
