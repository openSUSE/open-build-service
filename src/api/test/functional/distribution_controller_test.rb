require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'distribution_controller'

class DistributionControllerTest < ActionController::IntegrationTest 
  fixtures :all
 
  def setup
  end
  def teardown
# do not mess with production data, the controller must be fixed
#    FileUtils.unlink("#{Rails.root}/files/distributions.xml")
  end

  def test_put_and_get_list
    # FIXME: this is messing with production data, the controller must be fixed!
    if false

    data = '<distributions>
               <distribution vendor="openSUSE" version="Factory" id="opensuse-Factory">
                 <name>openSUSE Factory</name>
                 <project>openSUSE:Factory</project>
                 <reponame>openSUSE_Factory</reponame>
                 <repository>snapshot</repository>
                 <icon width="8" height="8" url="https://static.opensuse.org/distributions/logos/opensuse-Factory-8.png"/>
                 <icon width="16" height="16" url="https://static.opensuse.org/distributions/logos/opensuse-Factory-16.png"/>
                 <link>http://www.opensuse.org/</link>
               </distribution>
             </distributions>
             ' 

    ActionController::IntegrationTest::reset_auth
    put "/distributions", data
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    put "/distributions", data
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/distributions", data
    assert_response 200

    ActionController::IntegrationTest::reset_auth
    get "/distributions"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/distributions"
    assert_response :success
  
    end
  end
  
  # FIXME: write distribution schema and add a check with broken XML

end
