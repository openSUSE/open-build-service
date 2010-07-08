require File.dirname(__FILE__) + '/../test_helper'

class WizardControllerTest < ActionController::IntegrationTest 

  fixtures :all

  def setup
    @controller = SourceController.new
    @controller.start_test_backend

    Suse::Backend.put( '/source/kde4/_meta', DbProject.find_by_name('kde4').to_axml)
    Suse::Backend.put( '/source/kde4/kdelibs/_meta', DbPackage.find_by_name('kdelibs').to_axml)
  end

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
