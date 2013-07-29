require 'test_helper'

class LastEventsTest < ActionDispatch::IntegrationTest
  test "update lastevents" do
    BackendInfo.lastevents_nr = 1
    # before we should not have any in the database
    assert_operator LinkedPackage.count, :<, 3
    BackendInfo.first.update_last_events
    # at least 3 links found
    assert_operator LinkedPackage.count, :>=, 3

    # now call the same again without crashing
    count_before = LinkedPackage.count
    BackendInfo.first.update_last_events
    assert_equal LinkedPackage.count, count_before 

    # now create a link
    login_king
    delete "/source/BaseDistro2.0/pack2.linked/_link"
    assert_response :success

    # the link should disappear in database
    count_before = LinkedPackage.count
    BackendInfo.first.update_last_events
    assert_equal count_before - LinkedPackage.count, 1

    # now readd the link (also to fix the fixtures)
    put( '/source/BaseDistro2.0/pack2.linked/_link', "<link package=\"pack2\" cicount='copy' />")
    BackendInfo.first.update_last_events 
    assert_equal count_before, LinkedPackage.count
  end
  
end

