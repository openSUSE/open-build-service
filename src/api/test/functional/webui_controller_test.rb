require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WebuiControllerTest < ActionController::IntegrationTest
  
  def test_project_infos
    reset_auth
    get "/webui/project_infos?project=home:Iggy"
    assert_response 401

    prepare_request_with_user "Iggy", "asdfasdf"
    get "/webui/project_infos?project=home:Iggy"
    assert_response :success

  end
end
