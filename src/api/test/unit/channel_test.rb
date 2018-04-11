# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class ChannelTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    super
    @package = packages(:home_Iggy_TestPack)
    @channel = Channel.create(package: @package)
    User.current = nil
  end

  def teardown
    Timecop.return
    super
  end

  def test_parse_xml
    # pre condition check
    assert_equal 0, @channel.channel_binary_lists.size

    # a new channel
    axml = Xmlhash.parse(
      '<channel>
        <target project="home:Iggy" repository="10.2" id_template="UpdateInfoTag-&#37;Y-&#37;C" />
        <target project="BaseDistro" repository="BaseDistro_repo"><disabled/></target>
        <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
          <binary name="package" package="pack2" supportstatus="l3" />
          <binary name="does_not_exist" />
        </binaries>
        <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
          <binary name="package" package="pack2" supportstatus="l3" />
          <binary name="another_package_in_same_list" />
        </binaries>
      </channel>'
    )

    3.times do
      # just doing it multiple times to create and update
      @channel.update_from_xml(axml)
      @channel.save
      @channel.reload

      # check results
      assert_equal 2, @channel.channel_targets.size
      ct = @channel.channel_targets.first
      assert_equal 'UpdateInfoTag-%Y-%C', ct.id_template
      assert_equal Repository.find_by_project_and_name('home:Iggy', '10.2'), ct.repository
      assert_equal false, ct.disabled
      ct = @channel.channel_targets.last
      assert_nil ct.id_template
      assert_equal Repository.find_by_project_and_name('BaseDistro', 'BaseDistro_repo'), ct.repository
      assert_equal true, ct.disabled
      assert_equal 1, @channel.channel_binary_lists.size # two identical xml lists became one in db
      cbl = @channel.channel_binary_lists.first
      assert_equal 3, cbl.channel_binaries.size
      assert_equal 'package', cbl.channel_binaries.first.name
      assert_equal 'l3', cbl.channel_binaries.first.supportstatus
      assert_nil cbl.channel_binaries.first.binaryarch
      assert_nil cbl.channel_binaries.first.project
      assert_nil cbl.channel_binaries.first.architecture
    end

    # change some values
    axml = Xmlhash.parse(
      '<channel>
        <target project="home:Iggy" repository="10.2" id_template="NEW-&#37;Y-&#37;C" />
        <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
          <binary name="package" package="pack2" arch="x86_64" />
          <binary name="does_not_exist" supportstatus="l2" />
        </binaries>
      </channel>'
    )
    @channel.update_from_xml(axml)
    @channel.save
    @channel.reload
    assert_equal 1, @channel.channel_targets.size
    ct = @channel.channel_targets.first
    assert_equal 'NEW-%Y-%C', ct.id_template
    assert_equal Repository.find_by_project_and_name('home:Iggy', '10.2'), ct.repository
    assert_equal 1, @channel.channel_binary_lists.size
    cbl = @channel.channel_binary_lists.first
    assert_equal 2, cbl.channel_binaries.size
    assert_equal 'pack2', cbl.channel_binaries.where(name: 'package').first.package
    assert_nil cbl.channel_binaries.where(name: 'package').first.supportstatus
    assert_nil cbl.channel_binaries.where(name: 'package').first.binaryarch
    assert_nil cbl.channel_binaries.where(name: 'package').first.project
    assert_equal 'x86_64', cbl.channel_binaries.where(name: 'package').first.architecture.name

    assert_nil cbl.channel_binaries.where(name: 'does_not_exist').first.package
    assert_equal 'l2', cbl.channel_binaries.where(name: 'does_not_exist').first.supportstatus
  end
end
