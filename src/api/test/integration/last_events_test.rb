require 'test_helper'

class LastEventsTest < ActionDispatch::IntegrationTest
  test "update lastevents" do
    # before we should not have any in the database
    BackendPackage.delete_all
    assert_operator BackendPackage.count, :<, 3
    UpdatePackageMetaJob.new.perform
    # at least 3 links found
    assert_operator BackendPackage.links.count, :>=, 3

    # now call the same without crashing
    count_before = BackendPackage.links.count
    UpdatePackageMetaJob.new.perform
    UpdateNotificationEvents.new.perform
    assert_equal BackendPackage.links.count, count_before

    # now create a link
    login_king
    delete "/source/BaseDistro2.0/pack2.linked/_link"
    assert_response :success

    # the link should disappear in database
    count_before = BackendPackage.links.count
    UpdateNotificationEvents.new.perform
    assert_equal 1, count_before - BackendPackage.links.count

    # now readd the link (also to fix the fixtures)
    put('/source/BaseDistro2.0/pack2.linked/_link', "<link package=\"pack2\" cicount='copy' />")
    UpdateNotificationEvents.new.perform
    assert_equal count_before, BackendPackage.links.count
  end

end

