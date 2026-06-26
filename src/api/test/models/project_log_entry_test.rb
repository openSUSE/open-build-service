require_relative '../test_helper'

class ProjectLogEntryTest < ActiveSupport::TestCase
  fixtures :all
  set_fixture_class events: Event::Base

  test 'create from a commit' do
    event = events(:pack1_commit)
    entry = ProjectLogEntry.create_from(event.payload, event.created_at.to_s, event.class.name)
    assert_equal 'commit', entry.event_type
    assert_equal 'New revision of a package committed', entry.message
    assert_equal projects(:BaseDistro), entry.project
    assert_nil entry.user_name
    assert_equal packages(:BaseDistro_pack1), entry.package
    assert_equal Date.parse('2013-08-31'), entry.datetime.to_date
    assert_equal({ 'files' => "Added:\n  my_file\n\n", 'rev' => '1' }, entry.additional_info)
  end

  test 'create from commit for a deleted package' do
    event = events(:commit_for_deleted_package)
    entry = ProjectLogEntry.create_from(event.payload, event.created_at.to_s, event.class.name)
    assert_not entry.new_record?
    assert_equal projects(:'BaseDistro2.0'), entry.project
    assert_equal users(:Iggy), entry.user
    assert_equal BsRequest.find_by_number(1000), entry.bs_request
    assert_nil entry.package
    assert_equal 'isgone', entry.package_name
  end

  test 'create from build_success for a deleted project' do
    event = events(:build_success_from_deleted_project)
    entry = ProjectLogEntry.create_from(event.payload, event.created_at.to_s, event.class.name)
    assert entry.new_record?
    assert_nil entry.id
    assert_nil entry.project
  end

  test 'create from build_fail with deleted user and request' do
    event = events(:build_fails_with_deleted_user_and_request)
    entry = ProjectLogEntry.create_from(event.payload, event.created_at.to_s, event.class.name)
    assert_equal 'build_fail', entry.event_type
    assert_equal 'Package failed to build', entry.message
    assert_equal projects(:BaseDistro), entry.project
    assert_nil entry.user
    assert_equal 'no_longer_there', entry.user_name
    assert_nil entry.bs_request
    assert_equal({ 'repository' => '10.2', 'arch' => 'i586', 'rev' => '5' }, entry.additional_info)
  end
end
