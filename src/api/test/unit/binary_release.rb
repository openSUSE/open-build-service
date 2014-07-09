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
                              :binary_maintainer => "tom",
                             )
    sbr = BinaryRelease.find_by_repo_and_name( r, "package" )
    assert_equal sbr.first, br
    assert_equal sbr.first.binary_name, "package"
    assert_equal sbr.first.binary_version, "1"
    assert_equal sbr.first.binary_release, "2.3"
    assert_equal sbr.first.binary_arch, "noarch"
    assert_equal sbr.first.binary_supportstatus, "unsupported"
    assert_equal sbr.first.binary_maintainer, "tom"
    assert_equal sbr.first.binary_releasetime, Time.now
    sbr = BinaryRelease.find_by_repo_and_name( r, "package" )
    assert_equal sbr.first, br

    # cleanup works?
    id = sbr.first.id
    r.destroy
    assert_nil BinaryRelease.find_by_id(id)
  end

  def test_update_from_json_hash
    json = [{"arch"=>"i586", "binaryarch"=>"i586", "repository"=>"BaseDistro3_repo", "release"=>"1", "name"=>"delete_me", "project"=>"BaseDistro3", "version"=>"1.0", "package"=>"pack2"}, {"arch"=>"i586", "binaryarch"=>"i586", "name"=>"package", "repository"=>"BaseDistro3_repo", "release"=>"1", "project"=>"BaseDistro3", "version"=>"1.0", "package"=>"pack2"}, {"arch"=>"i586", "binaryarch"=>"src", "name"=>"package", "repository"=>"BaseDistro3_repo", "release"=>"1", "project"=>"BaseDistro3", "version"=>"1.0", "package"=>"pack2"}, {"binaryarch"=>"x86_64", "arch"=>"i586", "package"=>"pack2", "project"=>"BaseDistro3", "version"=>"1.0", "release"=>"1", "repository"=>"BaseDistro3_repo", "name"=>"package_newweaktags"}]

    r = Repository.find_by_project_and_repo_name("BaseDistro3", "BaseDistro3_repo")

    BinaryRelease.update_binary_releases_via_json(r, json)
  end

end
