# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'request_controller'

class GroupRequestTest < ActionController::IntegrationTest

  fixtures :all

  teardown do
    Timecop.return
  end

  def upload_request(filename)
    req = load_backend_file("request/#{filename}")
    post "/request?cmd=create", req
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    node.value :id
  end

  def test_set_and_get
    Timecop.freeze(2010, 7, 12)
    prepare_request_with_user "king", "sunflower"
    # make sure there is at least one
    id = upload_request("group")
    get "/request/#{id}"
    assert_response :success

    # 998 is new, so the group is new too
    assert_equal({"id" => id,
                  "action" => {"type" => "group", "grouped" => {"id" => "998"}},
                  "state" =>
                      {"name" => "new", "who" => "king", "when" => "2010-07-12T00:00:00", "comment" => {}},
                  "description" => {}
                 }, Xmlhash.parse(@response.body))
    Timecop.freeze(1)

    # try to create a cycle
    post "/request/#{id}?cmd=addrequest&newid=#{id}&comment=been+there"
    assert_response 400
    assert_xml_tag(:tag => "status", :attributes => {:code => 'cant_group_in_groups'})

    # try to submit nonsense
    post "/request/#{id}?cmd=addrequest&newid=Foobar&comment=been+there"
    assert_response 400
    assert_xml_tag(:tag => "status", :attributes => {:code => 'require_id'})

    # add another 'new' one
    adi = upload_request("group_1")
    post "/request/#{id}?cmd=addrequest&newid=#{adi}&comment=role+too"
    assert_response :success
    get "/request/#{id}"
    assert_response :success

    # state didn't change, only history
    assert_equal({"id" => id,
                  "action" => {"type" => "group", "grouped" => [{"id" => "998"}, {"id" => adi}]},
                  "state" =>
                      {"name" => "new", "who" => "king", "when" => "2010-07-12T00:00:00", "comment" => {}},
                  "description" => {}
                 }, Xmlhash.parse(@response.body))
    Timecop.freeze(1)

    # now one in review
    withr = upload_request("submit_with_review")
    post "/request/#{id}?cmd=addrequest&newid=#{withr}&comment=review+too"
    assert_response :success
    get "/request/#{id}"
    assert_response :success

    # state changed to review
    assert_equal({"id" => id,
                  "action" => {"type" => "group", "grouped" => [{"id" => "998"}, {"id" => adi}, {"id" => withr}]},
                  "state" =>
                      {"name" => "review", "who" => "king", "when" => "2010-07-12T00:00:02", "comment" => {}},
                  "description" => {}
                 }, Xmlhash.parse(@response.body))
    Timecop.freeze(1)
    # group_1 should be in review too now
    get "/request/#{adi}"
    assert_response :success
    assert_equal({"id" => adi,
                  "action" => {"type" => "add_role",
                               "target" => {"project" => "Apache", "package" => "apache2"},
                               "person" => {"name" => "Iggy", "role" => "bugowner"}},
                  "state" =>
                      {"name" => "review",
                       "who" => "king",
                       "when" => "2010-07-12T00:00:02",
                       "comment" => {}},
                  "description" => {}
                 }, Xmlhash.parse(@response.body))

    # now we revoke the group and adi should be new again
    post "/request/#{id}?cmd=changestate&newstate=revoked"
    assert_response :success
    Timecop.freeze(1)
    # group_1 should be in new again
    get "/request/#{adi}"
    assert_response :success
    assert_equal({"id" => adi,
                  "action" => {"type" => "add_role",
                               "target" => {"project" => "Apache", "package" => "apache2"},
                               "person" => {"name" => "Iggy", "role" => "bugowner"}},
                  "state" =>
                      {"name" => "new",
                       "who" => "king",
                       "when" => "2010-07-12T00:00:03",
                       "comment" => "removed from group #{id}"},
                  "history" => {"name" => "review", "who" => "king", "when" => "2010-07-12T00:00:02"},

                  "description" => {}
                 }, Xmlhash.parse(@response.body))

  end

  test "remove request" do
    Timecop.freeze(2010, 7, 12)
    prepare_request_with_user "king", "sunflower"
    id = upload_request("group")

    # now one in review
    withr = upload_request("submit_with_review")
    post "/request/#{id}?cmd=addrequest&newid=#{withr}&comment=review+too"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(:tag => "state", :attributes => {:name => "review"})

    post "/request/#{id}?cmd=removerequest&oldid=#{withr}&comment=remove+again"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    assert_xml_tag(:tag => "state", :attributes => {:name => "new"})

  end
end
