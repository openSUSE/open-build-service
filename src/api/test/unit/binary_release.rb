# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class BinaryReleaseTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    super
    User.current = nil
  end

  def teardown
    Timecop.return
  end

  def test_render_fixture
    r = Repository.find_by_project_and_name('BaseDistro3',
                                            'BaseDistro3_repo')
    br = BinaryRelease.where(repository: r).first
    xml = br.render_xml
    assert_xml_tag xml, tag: 'binary',
                        attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo',
                                         name: 'package', version: '1.0', release: '1', arch: 'i586' }
    assert_xml_tag xml, tag: 'maintainer', content: 'Iggy'
    assert_xml_tag xml, tag: 'operation', content: 'added'
    assert_xml_tag xml, tag: 'supportstatus', content: 'l3'
    assert_xml_tag xml, tag: 'updateinfo', attributes: { id: 'OBS-2014-42', version: '1' }
  end

  def test_create_and_find_entries
    project = Project.find_by_name('BaseDistro')
    repository = project.repositories.build(name: 'Dummy')
    Timecop.freeze(2010, 7, 12)
    binary_release = BinaryRelease.create(repository: repository,
                                          binary_name: 'package',
                                          binary_version: '1',
                                          binary_release: '2.3',
                                          binary_arch: 'noarch',
                                          binary_supportstatus: 'unsupported',
                                          binary_maintainer: 'tom')
    binary_releases_of_package = BinaryRelease.where(repository: repository, binary_name: 'package')
    assert_equal binary_releases_of_package.first, binary_release
    assert_equal binary_releases_of_package.first.binary_name, 'package'
    assert_equal binary_releases_of_package.first.binary_version, '1'
    assert_equal binary_releases_of_package.first.binary_release, '2.3'
    assert_equal binary_releases_of_package.first.binary_arch, 'noarch'
    assert_equal binary_releases_of_package.first.binary_supportstatus, 'unsupported'
    assert_equal binary_releases_of_package.first.binary_maintainer, 'tom'
    assert_equal binary_releases_of_package.first.binary_releasetime, Time.now

    # cleanup works?
    id = binary_releases_of_package.first.id
    repository.destroy
    assert_nil BinaryRelease.find_by_id(id)
  end

  def test_update_from_json_hash
    json = [{ 'arch' => 'i586', 'binaryarch' => 'i586', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'name' => 'delete_me', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'arch' => 'i586', 'binaryarch' => 'i586', 'name' => 'package', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'arch' => 'i586', 'binaryarch' => 'src', 'name' => 'package', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'binaryarch' => 'x86_64', 'arch' => 'i586', 'package' => 'pack2', 'project' => 'BaseDistro3',
             'version' => '1.0', 'release' => '1', 'repository' => 'BaseDistro3_repo',
             'name' => 'package_newweaktags', 'buildtime' => '1409642056' }]

    r = Repository.find_by_project_and_name('BaseDistro3', 'BaseDistro3_repo')

    BinaryRelease.update_binary_releases_via_json(r, json)
    count = BinaryRelease.all.length
    # no new entries
    BinaryRelease.update_binary_releases_via_json(r, json)
    assert_equal count, BinaryRelease.all.length

    # modify just one timestampe
    json = [{ 'arch' => 'i586', 'binaryarch' => 'i586', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'name' => 'delete_me', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'arch' => 'i586', 'binaryarch' => 'i586', 'name' => 'package', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'arch' => 'i586', 'binaryarch' => 'src', 'name' => 'package', 'repository' => 'BaseDistro3_repo',
             'release' => '1', 'project' => 'BaseDistro3', 'version' => '1.0',
             'package' => 'pack2', 'buildtime' => '1409642056' },
            { 'binaryarch' => 'x86_64', 'arch' => 'i586', 'package' => 'pack2', 'project' => 'BaseDistro3',
             'version' => '1.0', 'release' => '1', 'repository' => 'BaseDistro3_repo',
             'name' => 'package_newweaktags', 'buildtime' => '1409642057' }]
    BinaryRelease.update_binary_releases_via_json(r, json)
    assert_equal count, BinaryRelease.all.length - 1 # one entry added
  end
end
