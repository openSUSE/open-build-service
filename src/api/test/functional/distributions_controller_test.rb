require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class DistributionsControllerTest < ActionController::IntegrationTest
  fixtures :all

  test "should show distribution" do
    get distribution_path(id: distributions(:one).to_param)
    assert_response :success
    assert_equal({"id"=>{"type"=>"integer", "_content"=>"1"},
		  "link"=>"http://www.opensuse.org/",
		  "name"=>"openSUSE Factory",
		  "project"=>"openSUSE.org:openSUSE:Factory",
		  "reponame"=>"openSUSE_Factory",
		  "repository"=>"snapshot",
		  "vendor"=>"openSUSE",
		  "version"=>"Factory"}, Xmlhash.parse(@response.body))
  end

  test "should destroy distribution" do
    prepare_request_with_user "king", "sunflower"
    assert_difference('Distribution.count', -1) do
      delete distribution_path(id: distributions(:one).to_param)
      assert_response :success
    end
  end

  test "the old interface works" do
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

    reset_auth
    put "/distributions", data
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    put "/distributions", data
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    put "/distributions", data
    assert_response 200

    reset_auth
    get "/distributions"
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    get "/distributions"
    assert_response :success
  end
end
