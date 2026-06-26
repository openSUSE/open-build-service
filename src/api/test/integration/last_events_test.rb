require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class LastEventsTest < ActionDispatch::IntegrationTest
  def setup
    # ensure that the backend got started or we read, process and forget the indexed data.
    # of course only if our timing is bad :/
    super
    Backend::Test.start(wait_for_scheduler: true)
  end

  test 'update lastevents' do
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
    count_before = BackendPackage.links.count
    delete '/source/BaseDistro2.0/pack2.linked/_link'
    assert_response :success

    # the link should disappear in database
    UpdateNotificationEvents.new.perform
    assert_equal 1, count_before - BackendPackage.links.count

    # now readd the link (also to fix the fixtures)
    put('/source/BaseDistro2.0/pack2.linked/_link', params: "<link package=\"pack2\" cicount='copy' />")
    UpdateNotificationEvents.new.perform
    assert_equal count_before, BackendPackage.links.count
  end
end
