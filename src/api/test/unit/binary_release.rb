require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'faker'

SimpleCov.command_name 'test:api'

class BinaryReleaseTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    super
    User.current = nil
  end

  def teardown
    Timecop.return
  end

  def test_create_and_find_entries
    p = Project.find_by_name("BaseDistro")
    r = p.repositories.build(:name => "Dummy")
    Timecop.freeze(2010, 7, 12)
    br = BinaryRelease.create(:repository => r,
                              :binary_name => "package",
                              :binary_version => "1",
                              :binary_release => "2.3",
                              :binary_arch => "noarch",
                              :binary_supportstatus => "unsupported",
                             )
    sbr = BinaryRelease.find_by_repo_and_name( r, "package" )
    assert_equal sbr.first, br
    assert_equal sbr.first.binary_name, "package"
    assert_equal sbr.first.binary_version, "1"
    assert_equal sbr.first.binary_release, "2.3"
    assert_equal sbr.first.binary_arch, "noarch"
    assert_equal sbr.first.binary_supportstatus, "unsupported"
    assert_equal sbr.first.binary_releasetime, Time.now
    sbr = BinaryRelease.find_by_repo_and_name( r, "package" )
    assert_equal sbr.first, br

    # cleanup works?
    id = sbr.first.id
    r.destroy
    assert_nil BinaryRelease.find_by_id(id)
  end

end
