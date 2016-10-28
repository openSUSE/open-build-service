# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WizardControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_wizard
    prepare_request_valid_user

    get "/source/kde4/kdelibs/_wizard"
    assert_response 403
    assert_match(/no permission to change package/, @response.body)

    prepare_request_with_user "fredlibs", "buildservice"

    get "/source/kde4/kdelibs-not/_wizard"
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_package" }

    get "/source/kde4/kdelibs/_wizard"
    assert_response 200
    assert_xml_tag tag: 'wizard'

    get "/source/HiddenProject/pack/_wizard"
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_project" }

    # hidden project user should be able to access wizard
    prepare_request_with_user "hidden_homer", "buildservice"

    get "/source/HiddenProject/pack/_wizard"
    assert_response 200
    assert_xml_tag tag: 'wizard'

    # Admin user should be able to access wizard
    login_king

    get "/source/HiddenProject/pack/_wizard"
    assert_response 200
    assert_xml_tag tag: 'wizard'
  end
end
