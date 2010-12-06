require File.dirname(__FILE__) + '/../test_helper'

class WizardControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def test_wizard
    prepare_request_valid_user
  
    get "/source/kde4/kdelibs/_wizard"
    assert_response 403
    assert_match(/no permission to change package/, @response.body)

    prepare_request_with_user "fredlibs", "geröllheimer"

    get "/source/kde4/kdelibs-not/_wizard"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    get "/source/kde4/kdelibs/_wizard"
    assert_response 200
    assert_tag :tag => 'wizard'

    # ACL 'access' tests
    #
    # non-access member should get unknown package (for unknown project)
    get "/source/HiddenProject/pack/_wizard"
    assert_response 404
    assert_match(/unknown_package/, @response.body)

    # hidden project user should be able to access wizard
    prepare_request_with_user "hidden_homer", "homer"

    get "/source/HiddenProject/pack/_wizard"
    assert_response 200
    assert_tag :tag => 'wizard'

    # Admin user should be able to access wizard
    prepare_request_with_user "king", "sunflower"

    get "/source/HiddenProject/pack/_wizard"
    assert_response 200
    assert_tag :tag => 'wizard'
  end
 
end
