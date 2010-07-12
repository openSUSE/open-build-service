require File.dirname(__FILE__) + '/../test_helper'

class WizardControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def test_wizard
    prepare_request_valid_user
  
    get "/source/kde4/kdelibs/_wizard"
    assert_response 403
    assert_match /no permission to change package/, @response.body

    prepare_request_with_user "fredlibs", "geröllheimer"

    get "/source/kde4/kdelibs-not/_wizard"
    assert_response 404
    assert_match /unknown package 'kdelibs-not' in project 'kde4'/, @response.body

    get "/source/kde4/kdelibs/_wizard"
    assert_response 200
    assert_tag :tag => 'wizard'
  end
 
end
