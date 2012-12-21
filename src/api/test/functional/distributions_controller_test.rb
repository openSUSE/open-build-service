require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class DistributionsControllerTest < ActionController::IntegrationTest
  fixtures :all
  
  teardown do
    WebMock.reset!
  end

  test "should show distribution" do
    get distribution_path(id: distributions(:one).to_param)
    assert_response :success
    assert_equal({"id"=>{"type"=>"integer", "_content"=>"1"},
                   "id"=>{"type"=>"integer", "_content"=>"1"},
                   "link"=>"http://www.opensuse.org/",
                   "name"=>"OBS Base",
                   "project"=>"BaseDistro2.0",
                   "reponame"=>"Base_repo",
                   "repository"=>"BaseDistro2_repo",
                   "vendor"=>"OBS",
                   "version"=>"Base"}, Xmlhash.parse(@response.body))
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
    assert_no_xml_tag :tag => "project", :content => "RemoteInstance:openSUSE:12.2"
  end

  test "remotes work" do
    prepare_request_with_user "tom", "thunder"
    
    fake_distribution_body = File.open(Rails.root.join("test/fixtures/backend/distributions.xml")).read

    # using mocha has the disadvantage of not testing the complete function
    #Distribution.stubs(:load_distributions_from_remote).returns(fake_distribution_body)

    stub_request(:get, "http://localhost:3200/distributions.xml").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(status: 200, body: fake_distribution_body, headers: {})

    get "/distributions/include_remotes"
    assert_response :success

    # validate rendering and modifications of a remote repo
    assert_xml_tag :tag => "name", :content => "openSUSE 12.2" # remote 1
    assert_xml_tag :tag => "name", :content => "openSUSE Factory" # remote 2
    assert_xml_tag :tag => "name", :content => "OBS Base" # local only
    assert_xml_tag :tag => "project", :content => "RemoteInstance:openSUSE:12.2"
    assert_xml_tag :tag => "reponame", :content => "openSUSE_12.2"
    assert_xml_tag :tag => "repository", :content => "standard"
    assert_xml_tag :tag => "link", :content => "http://www.opensuse.org/"
    assert_xml_tag :tag => "icon", :attributes => { :url => "https://static.opensuse.org/distributions/logos/opensuse-12.2-8.png", :width => "8", :height => "8" }

  end


  test "we survive remote instances timeouts" do
    stub_request(:get, "http://localhost:3200/distributions.xml").to_timeout
    get "/distributions/include_remotes"
    assert_response :success
    # only the one local is included
    assert_xml_tag tag: "distributions", children: { count: 1}
  end
end
