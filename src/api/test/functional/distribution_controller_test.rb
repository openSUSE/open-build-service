require File.dirname(__FILE__) + '/../test_helper'
require 'distribution_controller'

class DistributionControllerTest < ActionController::IntegrationTest 
  fixtures :all

  @data = '<distributions>
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
 
  def setup
  end

  def test_get_list
    ActionController::IntegrationTest::reset_auth
    get "/distribution"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/distribution"
    assert_response :success
  end
  
  def test_put_list
    ActionController::IntegrationTest::reset_auth
    put "/distribution", @data
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    put "/distribution", @data
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/distribution", @data
    assert_response 200
  end
  
  # FIXME: write distribution schema and add a check with broken XML

end
