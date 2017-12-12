# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'json'
# require '/usr/lib64/ruby/gems/1.9.1/gems/perftools.rb-2.0.0/lib/perftools.so'

class ProjectTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects( :home_Iggy )
  end

  def test_maintained_project_names
    project = Project.create(name: "Z")
    ["A", "B", "C"].each do |project_name|
      project.maintained_projects.create(project: Project.create(name: project_name))
    end

    assert_equal ["A", "B", "C"], project.maintained_project_names
  end

  def test_flags_inheritance
    User.current = users( :Iggy )

    project = Project.create(name: "home:Iggy:flagtest")

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy:flagtest'>
        <title>Iggy's Flag Testing Project</title>
        <description>dummy</description>
        <build>
          <enable                repository='SLE_11_SP4'/>
          <enable arch='i586'    />
          <enable arch='x86_64'  repository='openSUSE_Leap_42.1'/>
          <enable arch='i586'    repository='SLE_11_SP4'/>
        </build>
        <repository name='openSUSE_Leap_42.1'>
          <arch>x86_64</arch>
        </repository>
        <repository name='openSUSE_Leap_42.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_11_SP4'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_12_SP1'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
       </project>"
    )

    project.update_from_xml(axml)
    project.store

    # test if all project build flags are 'enable'
    project.get_flags('build').each do |repo|
      repo[1].each do |flag|
        assert_equal 'enable', flag.status
      end
    end

    package1 = project.packages.create(name: "test1")
    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='test1' project='home:Iggy:flagtest'>
        <title>My Test package 1</title>
        <description></description>
        <build>
          <enable                repository='SLE_11_SP4'/>
          <enable arch='i586'    />
          <disable/>
        </build>
      </package>"
    )

    package1.update_from_xml(axml)
    package1.store
    package1.reload

    # check for the row and column which are 'enabled'
    assert_equal 4, project.flags.of_type('build').size
    assert_equal 'i586', project.flags.of_type('build')[1].architecture.name
    package1.get_flags('build').each do |repo|
      repo[1].each do |flag|
        if flag.repo == 'SLE_11_SP4'
          assert_equal 'enable', flag.status
        elsif flag.architecture_id == project.flags.of_type('build')[1].architecture.id
          assert_equal 'enable', flag.status
        else
          assert_equal 'disable', flag.status
        end
      end
    end

    package2 = project.packages.create(name: "test2")
    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='test2' project='home:Iggy:flagtest'>
        <title>My Test package 2</title>
        <description></description>
        <build>
          <disable/>
        </build>
      </package>"
    )

    package2.update_from_xml(axml)
    package2.store

    # the all 'disable' build flag shall overwrite the project setting
    package2.get_flags('build').each do |repo|
      repo[1].each do |flag|
        assert_equal 'disable', flag.status
      end
    end

    axml = Xmlhash.parse(
      "<project name='home:Iggy:flagtest'>
        <title>Iggy's Flag Testing Project</title>
        <description>dummy</description>
        <build>
          <enable             repository='SLE_11_SP4' />
          <disable/>
        </build>
        <useforbuild>
          <disable/>
        </useforbuild>
        <repository name='openSUSE_Leap_42.1'>
          <arch>x86_64</arch>
        </repository>
        <repository name='openSUSE_Leap_42.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_11_SP4'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_12_SP1'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
    )

    project.update_from_xml!(axml)
    project.store
    project.reload

    assert_equal 5, project.get_flags('build').size
    assert_equal 3, project.get_flags('build')["all"].size

    flag_test = project.get_flags('build')["SLE_11_SP4"][0]
    assert_equal 'enable', flag_test.status
    assert_equal 'enable', flag_test.effective_status
    assert_equal 'disable', flag_test.default_status

    flag_all = project.get_flags('build')["all"][0]
    assert_equal 'disable', flag_all.status
    assert_equal 'disable', flag_all.effective_status
    assert_equal 'enable', flag_all.default_status

    assert_equal 5, project.get_flags('useforbuild').size
    assert_equal 3, project.get_flags('useforbuild')["all"].size

    flag_useforbuild_all = project.get_flags('useforbuild')["all"][0]
    assert_equal 'disable', flag_useforbuild_all.status
    assert_equal 'disable', flag_useforbuild_all.effective_status
    assert_equal 'enable', flag_useforbuild_all.default_status

    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='test2' project='home:Iggy:flagtest'>
        <title>My Test package 2</title>
        <description></description>
        <build>
          <disable            repository='SLE_12_SP1' />
          <enable/>
        </build>
        <useforbuild>
          <enable/>
        </useforbuild>
      </package>"
    )

    package2.update_from_xml(axml)
    package2.store
    package2.reload

    assert_equal 5, package2.get_flags('build').size
    assert_equal 3, package2.get_flags('build')["all"].size

    flag_test = package2.get_flags('build')["SLE_12_SP1"][0]
    assert_equal 'disable', flag_test.status
    assert_equal 'disable', flag_test.effective_status
    assert_equal 'enable', flag_test.default_status

    flag_build_all = package2.get_flags('build')["all"][0]
    assert_equal 'enable',  flag_build_all.status
    assert_equal 'enable',  flag_build_all.effective_status
    assert_equal 'disable', flag_build_all.default_status

    assert_equal 5, package2.get_flags('useforbuild').size
    assert_equal 3, package2.get_flags('useforbuild')["all"].size

    flag_useforbuild_all = package2.get_flags('useforbuild')["all"][0]
    assert_equal 'enable', flag_useforbuild_all.status
    assert_equal 'enable', flag_useforbuild_all.effective_status
    assert_equal 'disable', flag_useforbuild_all.default_status

    package3 = project.packages.create(name: "test3")
    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='test3' project='home:Iggy:flagtest'>
        <title>My Test package 3</title>
        <description></description>
        <build>
          <enable               repository='SLE_11_SP4' />
          <enable               repository='SLE_12_SP1' />
          <disable arch='i586'  repository='SLE_12_SP1' />
          <disable arch='i586'  />
        </build>
        <useforbuild>
          <enable/>
        </useforbuild>
      </package>"
    )

    package3.update_from_xml(axml)
    package3.store
    package3.reload

    assert_equal 5, package3.get_flags('build').size
    assert_equal 3, package3.get_flags('build')["all"].size

    flag_test = package3.get_flags('build')["SLE_12_SP1"][1]
    assert_equal 'i586',    flag_test.architecture.name
    assert_equal 'disable', flag_test.status
    assert_equal 'disable', flag_test.effective_status
    assert_equal 'enable',  flag_test.default_status

    flag_test = package3.get_flags('build')["SLE_11_SP4"][0]
    assert_equal 'enable', flag_test.status
    assert_equal 'enable', flag_test.effective_status
    assert_equal 'disable', flag_test.default_status

    flag_test = package3.get_flags('build')["all"][0]
    assert_equal 'disable', flag_test.status
    assert_equal 'disable', flag_test.effective_status
    assert_equal 'disable', flag_test.default_status

    # now the final test: check all flags default in project and package
    project2 = Project.create(name: "home:Iggy:flagtest2")
    axml = Xmlhash.parse(
      "<project name='home:Iggy:flagtest2'>
        <title>Iggy's Flag Testing Project 2</title>
        <description>project to test all flag defaults</description>
        <build>
        </build>
        <publish>
        </publish>
        <useforbuild>
        </useforbuild>
        <debuginfo>
        </debuginfo>
        <repository name='openSUSE_Leap_42.1'>
          <arch>x86_64</arch>
        </repository>
        <repository name='openSUSE_Leap_42.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_11_SP4'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
        <repository name='SLE_12_SP1'>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
    )

    project2.update_from_xml(axml)
    project2.store
    project2.reload

    # test if all project flags are default for a new project
    allflags = ['build', 'publish', 'useforbuild', 'binarydownload', 'access', 'lock', 'debuginfo']
    allflags.each do |flagtype|
      project2.get_flags(flagtype).each do |repo|
        repo[1].each do |flag|
          assert_equal Flag.default_status(flagtype), flag.effective_status
          assert_equal Flag.default_status(flagtype), flag.default_status
          assert_equal Flag.default_status(flagtype), flag.status
        end
      end
    end

    package4 = project2.packages.create(name: "test4")
    axml = Xmlhash.parse(
      "<package name='test4' project='home:Iggy:flagtest2'>
        <title>My Test package 4</title>
        <description>package to test all default flags</description>
        <build>
        </build>
        <publish>
        </publish>
        <useforbuild>
        </useforbuild>
        <debuginfo>
        </debuginfo>
      </package>"
    )

    package4.update_from_xml(axml)
    package4.store
    package4.reload

    # test if all package flags are default for a new package
    allflags.each do |flagtype|
      assert_equal 5, package4.get_flags(flagtype).size
      package4.get_flags(flagtype).each do |repo|
        repo[1].each do |flag|
          assert_equal Flag.default_status(flagtype), flag.status
          assert_equal Flag.default_status(flagtype), flag.effective_status
          assert_equal Flag.default_status(flagtype), flag.default_status
        end
      end
    end

    # this is the end
    project.destroy
    project2.destroy
  end

  def test_release_targets_ng
    User.current = User.find_by_login "king"

    project = Project.create(name: "ABC", kind: "maintenance")
    project.store

    subproject = Project.create(name: "ABC:D", kind: "maintenance_incident")
    subproject.store

    repo_1 = Repository.create(name: "repo_1", db_project_id: subproject.id)
    repo_2 = Repository.create(name: "repo_2", db_project_id: subproject.id)
    repo_1.release_targets.create(trigger: "maintenance", target_repository_id: repo_2.id)

    package = subproject.packages.create(name: "test2")
    package.flags.create(flag: :build, status: "enable", repo: "repo_1")

    Patchinfo.new.create_patchinfo("ABC:D", "_patchinfo", { comment:  "patchinfo summary" })

    result = subproject.reload.release_targets_ng
    assert_equal ["ABC:D"], result.keys
    assert_equal "repo_1",  result["ABC:D"][:reponame]

    assert_equal 1, result["ABC:D"][:packages].count
    assert_equal package.id, result["ABC:D"][:packages].first.id
    assert_equal "test2", result["ABC:D"][:packages].first.name

    assert_equal "patchinfo summary", result["ABC:D"][:patchinfo][:summary]
    assert_equal "recommended",       result["ABC:D"][:patchinfo][:category]

    assert_nil result["ABC:D"][:patchinfo][:stopped]
  ensure
    # Prevent AAAPreConsistency check to fail
    project.destroy
    subproject.destroy
  end

  def test_flags_to_axml
    # check precondition
    assert_equal 2, @project.flags.of_type('build').size
    assert_equal 2, @project.flags.of_type('publish').size

    xml_string = @project.to_axml
    # puts xml_string

    # check the results
    assert_xml_tag xml_string, tag: :project, children: { count: 1, only: { tag: :build } }
    assert_xml_tag xml_string, parent: :project, tag: :build, children: { count: 2 }

    assert_xml_tag xml_string, tag: :project, children: { count: 1, only: { tag: :publish } }
    assert_xml_tag xml_string, parent: :project, tag: :publish, children: { count: 2 }
  end

  def test_add_new_flags_from_xml
    User.current = users( :Iggy )

    # precondition check
    @project.flags.delete_all
    @project.reload
    assert_equal 0, @project.flags.size

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <build>
          <disable repository='10.2' arch='i586'/>
        </build>
        <publish>
          <enable repository='10.2' arch='x86_64'/>
        </publish>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
      </project>"
    )

    position = 1
    %w(build publish debuginfo).each do |flagtype|
      position = @project.update_flags(axml, flagtype, position)
    end

    @project.save
    @project.reload

    # check results
    assert_equal 1, @project.flags.of_type('build').size
    assert_equal 'disable', @project.flags.of_type('build')[0].status
    assert_equal '10.2', @project.flags.of_type('build')[0].repo
    assert_equal 'i586', @project.flags.of_type('build')[0].architecture.name
    assert_equal 1, @project.flags.of_type('build')[0].position
    assert_nil @project.flags.of_type('build')[0].package
    assert_equal 'home:Iggy', @project.flags.of_type('build')[0].project.name

    assert_equal 1, @project.flags.of_type('publish').size
    assert_equal 'enable', @project.flags.of_type('publish')[0].status
    assert_equal '10.2', @project.flags.of_type('publish')[0].repo
    assert_equal 'x86_64', @project.flags.of_type('publish')[0].architecture.name
    assert_equal 2, @project.flags.of_type('publish')[0].position
    assert_nil @project.flags.of_type('publish')[0].package
    assert_equal 'home:Iggy', @project.flags.of_type('publish')[0].project.name

    assert_equal 1, @project.flags.of_type('debuginfo').size
    assert_equal 'disable', @project.flags.of_type('debuginfo')[0].status
    assert_equal '10.0', @project.flags.of_type('debuginfo')[0].repo
    assert_equal 'i586', @project.flags.of_type('debuginfo')[0].architecture.name
    assert_equal 3, @project.flags.of_type('debuginfo')[0].position
    assert_nil @project.flags.of_type('debuginfo')[0].package
    assert_equal 'home:Iggy', @project.flags.of_type('debuginfo')[0].project.name
  end

  def test_delete_flags_through_xml
    User.current = users( :Iggy )

    # check precondition
    assert_equal 2, @project.flags.of_type('build').size
    assert_equal 2, @project.flags.of_type('publish').size

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
    )

    @project.update_all_flags(axml)
    assert_equal 0, @project.flags.of_type('build').size
    assert_equal 0, @project.flags.of_type('publish').size
  end

  def test_store_axml
    User.current = users( :Iggy )

    original = @project.to_axml

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
        <url></url>
        <disable/>
      </project>"
    )

    @project.update_from_xml!(axml)
    @project.save!

    assert_equal 0, @project.flags.of_type('build').size
    assert_equal 1, @project.flags.of_type('debuginfo').size

    @project.update_from_xml!(Xmlhash.parse(original))
    @project.save!
  end

  def test_ordering
    User.current = users(:Iggy)

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>local</arch>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
    )
    @project.update_from_xml!(axml)
    @project.reload

    xml = @project.render_xml

    # validate i586 is in the middle
    assert_xml_tag xml, tag: :arch, content: 'i586', after: { tag: :arch, content: 'local' }
    assert_xml_tag xml, tag: :arch, content: 'i586', before: { tag: :arch, content: 'x86_64' }

    # now verify it's not happening randomly
    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>i586</arch>
          <arch>x86_64</arch>
          <arch>local</arch>
        </repository>
      </project>"
    )
    @project.update_from_xml!(axml)

    xml = @project.render_xml

    # validate x86_64 is in the middle
    assert_xml_tag xml, tag: :arch, content: 'x86_64', after: { tag: :arch, content: 'i586' }
    assert_xml_tag xml, tag: :arch, content: 'x86_64', before: { tag: :arch, content: 'local' }
  end

  def test_maintains
    User.current = users(:Iggy)

    # project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
        </maintenance>
      </project>"
    )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, tag: :maintains, attributes: { project: "BaseDistro" }

    # add one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
    )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, tag: :maintains, attributes: { project: "BaseDistro" }
    assert_xml_tag xml, tag: :maintains, attributes: { project: "BaseDistro2.0" }

    # remove one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
    )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, tag: :maintains, attributes: { project: "BaseDistro" }
    assert_xml_tag xml, tag: :maintains, attributes: { project: "BaseDistro2.0" }
    assert_xml_tag xml, tag: :maintenance

    # drop entire <maintenance> defs
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
    )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, tag: :maintenance
  end

  test "duplicated repos" do
    User.current = users( :king )
    orig = @project.render_xml

    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='10.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='10.2'>
          <arch>i586</arch>
        </repository>
      </project>"
    )
    assert_raise(ActiveRecord::RecordInvalid) do
      Project.transaction do
        @project.update_from_xml!(axml)
      end
    end
    @project.reload
    assert_equal orig, @project.render_xml
  end

  test "duplicated repos with remote" do
    User.current = users( :Iggy )
    orig = @project.render_xml

    xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
  </repository>
</project>
END
    axml = Xmlhash.parse(xml)
    assert_raise(ActiveRecord::RecordInvalid) do
      Project.transaction do
        @project.update_from_xml!(axml)
      end
    end
    @project.reload
    assert_equal orig, @project.render_xml
  end

  test "not duplicated repos with remote" do
    User.current = users( :Iggy )
    xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_2">
    <path project="RemoteInstance:remote_project_2" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
</project>
END
    axml = Xmlhash.parse(xml)
    Project.transaction do
      @project.update_from_xml!(axml)
    end
    @project.reload
    assert_equal xml, @project.render_xml
  end

  def test_handle_project_links
    Backend::Test.start
    User.current = users( :Iggy )

    # project A
    axml = Xmlhash.parse(
      "<project name='home:Iggy:A'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy' />
      </project>"
    )
    project_a = Project.create( name: "home:Iggy:A" )
    project_a.update_from_xml!(axml)
    project_a.store

    # project B
    axml = Xmlhash.parse(
      "<project name='home:Iggy:B'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy:A' />
      </project>"
    )
    project_b = Project.create( name: "home:Iggy:B" )
    project_b.update_from_xml!(axml)
    project_b.store

    # validate xml
    xml_string = project_a.to_axml
    assert_xml_tag xml_string, tag: :link, attributes: { project: "home:Iggy" }
    xml_string = project_b.to_axml
    assert_xml_tag xml_string, tag: :link, attributes: { project: "home:Iggy:A" }

    project_a.destroy
    project_b.reload
    xml_string = project_b.to_axml
    assert_no_xml_tag xml_string, tag: :link
    project_b.destroy
  end

  def test_repository_with_download_url
    User.current = users( :king )

    prj = Project.new(name: "DoD")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='DoD'>
                              <title/>
                              <description/>
                              <repository name='standard'>
                                <download arch='i586' url='http://me.org' repotype='rpmmd'>
                                 <archfilter>i686,i586,noarch</archfilter>
                                 <master url='http://download.opensuse.org' sslfingerprint='0815' />
                                 <pubkey>grfzl</pubkey>
                                </download>
                                <arch>i586</arch>
                              </repository>
                            </project>"
    ))

    xml = prj.to_axml
    assert_xml_tag xml, tag: :download, attributes: {arch: "i586", url: "http://me.org", repotype: "rpmmd"}
    assert_xml_tag xml, tag: :archfilter, content: "i686,i586,noarch"
    assert_xml_tag xml, tag: :master, attributes: {url: "http://download.opensuse.org", sslfingerprint: "0815"}
    assert_xml_tag xml, tag: :pubkey, content: "grfzl"
  end

  def test_validate_remote_permissions
    # Single repository elements
    request_data = Xmlhash.parse(load_backend_file("download_on_demand/project_with_dod.xml"))
    User.current = users(:king)
    assert Project.validate_remote_permissions(request_data).empty?
    User.current = users(:user5)
    assert_equal "Admin rights are required to change projects using remote resources",
                 Project.validate_remote_permissions(request_data)[:error]

    # With multiple repository elements
    request_data = Xmlhash.parse("
      <project name='home:user5'>
      <title>User5 Home Project</title>
      <description/>
      <person userid='user5' role='maintainer'/>
      <repository name='standard'>
        <download arch='i586' url='http://mola.org2' repotype='rpmmd'>
          <archfilter>i586, noarch</archfilter>
          <master url='http://opensuse.org' sslfingerprint='asdfasd'/>
          <pubkey>3jnlkdsjfoisdjf0932juro2ikjfdslñkfj</pubkey>
        </download>
        <arch>i586</arch>
        <arch>x86_64</arch>
      </repository>
      <repository name='images'>
        <arch>x86_64</arch>
        </repository>
      </project>
    ")
    User.current = users(:king)
    assert Project.validate_remote_permissions(request_data).empty?
  end

  def test_repository_path_sync
    User.current = users( :king )

    prj = Project.new(name: "Enterprise-SP0:GA")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='Enterprise-SP0:GA'>
                              <title/>
                              <description/>
                              <repository name='sp0_ga' />
                            </project>"
    ))
    prj = Project.new(name: "Enterprise-SP0:Update")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='Enterprise-SP0:Update' kind='maintenance_release'>
                              <title/>
                              <description/>
                              <repository name='sp0_update' >
                                <path project='Enterprise-SP0:GA' repository='sp0_ga' />
                              </repository>
                            </project>"
    ))
    prj = Project.new(name: "Enterprise-SP1:GA")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='Enterprise-SP1:GA'>
                              <title/>
                              <description/>
                              <repository name='sp1_ga' >
                                <path project='Enterprise-SP0:GA' repository='sp0_ga' />
                              </repository>
                            </project>"
    ))
    prj = Project.new(name: "Enterprise-SP1:Update")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='Enterprise-SP1:Update' kind='maintenance_release'>
                              <title/>
                              <description/>
                              <repository name='sp1_update' >
                                <path project='Enterprise-SP1:GA' repository='sp1_ga' />
                                <path project='Enterprise-SP0:Update' repository='sp0_update' />
                              </repository>
                            </project>"
    ))
    prj = Project.new(name: "Enterprise-SP1:Channel:Server")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='Enterprise-SP1:Channel:Server'>
                              <title/>
                              <description/>
                              <repository name='channel' >
                                <path project='Enterprise-SP1:Update' repository='sp1_update' />
                              </repository>
                            </project>"
    ))
    # this is what the classic add_repository call is producing:
    prj = Project.new(name: "My:Branch")
    prj.update_from_xml!( Xmlhash.parse(
                            "<project name='My:Branch'>
                              <title/>
                              <description/>
                              <repository name='Channel_Server' >
                                <path project='Enterprise-SP1:Channel:Server' repository='channel' />
                              </repository>
                              <repository name='my_branch_sp0_update' >
                                <path project='Enterprise-SP0:Update' repository='sp0_update' />
                              </repository>
                              <repository name='my_branch_sp1_update' >
                                <path project='Enterprise-SP1:Update' repository='sp1_update' />
                              </repository>
                            </project>"
    ))
    # however, this is not correct, because my:branch (or an incident)
    # is providing in this situation often a package in SP0:Update which
    # must be used for building the package in sp1 repo.
    # Since the order of adding the repositories is not fixed or can even
    # be extended with later calls, we need to sync this always after finishing a
    # a setup of new branched packages with this sync function:
    xml = prj.to_axml
    assert_xml_tag xml, tag: :repository, attributes: {name: "my_branch_sp1_update"},
                        children: { count: 1, only: { tag: :path } }

    assert_no_xml_tag xml, tag: :path, attributes: { project: "My:Branch", repository: "my_branch_sp0_update" }
    prj.reload
    prj.sync_repository_pathes
    xml = prj.to_axml
    assert_xml_tag xml, tag: :repository, attributes: {name: "my_branch_sp1_update"},
                        children: { count: 2, only: { tag: :path } }
    assert_xml_tag xml, tag: :path, attributes: { project: "My:Branch", repository: "my_branch_sp0_update" }
    # untouched
    assert_xml_tag xml, tag: :repository, attributes: {name: "my_branch_sp0_update"},
                        children: { count: 1, only: { tag: :path } }
    assert_xml_tag xml, parent: { tag: :repository, attributes: {name: "Channel_Server"} },
                        tag: :path, attributes: {project: "Enterprise-SP1:Channel:Server", repository: "channel"}

    # must not change again anything
    prj.sync_repository_pathes
    assert_equal xml, prj.to_axml
  end

  # helper
  def put_flags(flags)
    flags.each do |flag|
      if flag.architecture.nil?
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture} \t #{flag.repo} \t #{flag.position}"
      else
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture.name} \t #{flag.repo} \t #{flag.position}"
      end
    end
  end

  test 'invalid names' do # spec/models/project_spec.rb
    # no ::
    assert !Project.valid_name?('home:M0ses:raspi::qtdesktop')
    assert !Project.valid_name?(10)
    assert !Project.valid_name?('')
    assert !Project.valid_name?('_foobar')
    assert !Project.valid_name?("4" * 250)
  end

  test 'valid name' do # spec/models/project_spec.rb
    assert Project.valid_name?("foobar")
    assert Project.valid_name?("Foobar_")
    assert Project.valid_name?("foo1234")
    assert Project.valid_name?("4" * 200)
  end

  def test_cycle_handling
    User.current = users( :king )

    prj_a = Project.new(name: "Project:A")
    prj_a.update_from_xml!(Xmlhash.parse(
                             "<project name='Project:A'>
                               <title/>
                               <description/>
                             </project>"
    ))
    prj_a.save!
    prj_b = Project.new(name: "Project:B")
    prj_b.update_from_xml!(Xmlhash.parse(
                             "<project name='Project:B'>
                               <title/>
                               <description/>
                               <link project='Project:A'/>
                             </project>"
    ))
    prj_b.save!
    prj_a.update_from_xml!(Xmlhash.parse(
                             "<project name='Project:A'>
                               <title/>
                               <description/>
                               <link project='Project:B'/>
                             </project>"
    ))
    prj_a.save!

    assert_equal [], prj_a.expand_all_packages
    assert_equal 2,  prj_a.expand_all_projects.length
  end

  test 'exists_by_name' do
    User.current = users( :Iggy )

    assert Project.exists_by_name('home:Iggy')
    assert Project.exists_by_name('RemoteInstance')
    assert Project.exists_by_name('RemoteInstance:NoMatterIfThisProjectExistsOrNot')
    assert Project.exists_by_name('RemoteInstance:NoMatter:IfThisProjectExistsOrNot')
    assert_not Project.exists_by_name('NonExistingProject')
    assert_not Project.exists_by_name('Some:NonExistingProject')
    assert_not Project.exists_by_name('HiddenProject')
    assert_not Project.exists_by_name('HiddenRemoteInstance')
  end

  test 'validate_maintenance_xml_attribute returns an error if User can not modify target project' do
    User.current = users(:tom)
    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <maintenance><maintains project="Apache"></maintains></maintenance>
      </project>
    XML

    actual = Project.validate_maintenance_xml_attribute(Xmlhash.parse(xml))
    expected = { error: "No write access to maintained project Apache" }
    assert_equal actual, expected
  end

  test 'validate_maintenance_xml_attribute returns no error if User can modify target project' do
    User.current = users(:king)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <maintenance><maintains project="Apache"></maintains></maintenance>
      </project>
    XML

    actual = Project.validate_maintenance_xml_attribute(Xmlhash.parse(xml))
    assert_equal actual, {}
  end

  test 'validate_link_xml_attribute returns no error if target project is not disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <link project="Apache"></link>
      </project>
    XML

    actual = Project.validate_link_xml_attribute(Xmlhash.parse(xml), project.name)
    assert_equal actual, {}
  end

  test 'validate_link_xml_attribute returns an error if target project access is disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <link project="home:Iggy"></link>
      </project>
    XML

    flag = project.add_flag('access', 'disable')
    flag.save

    actual = Project.validate_link_xml_attribute(Xmlhash.parse(xml), 'the_project')
    expected = { error: "Project links work only when both projects have same read access protection level: the_project -> home:Iggy" }
    assert_equal actual, expected
  end

  test 'validate_repository_xml_attribute returns no error if project access is not disabled' do
    User.current = users(:Iggy)

    xml = <<-XML.strip_heredoc
      <project name='other_project'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'other_project')
    expected = {}
    assert_equal actual, expected
  end

  test 'returns an error if repository access is disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    flag = project.add_flag('access', 'disable')
    flag.save

    xml = <<-XML.strip_heredoc
      <project name='other_project'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'other_project')
    expected = { error: "The current backend implementation is not using binaries from read access protected projects home:Iggy" }
    assert_equal actual, expected
  end

  test 'returns no error if target project equals project' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    flag = project.add_flag('access', 'disable')
    flag.save

    xml = <<-XML.strip_heredoc
      <project name='home:Iggy'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'home:Iggy')
    expected = { }
    assert_equal actual, expected
  end

  test 'get_removed_repositories returns all repositories if new_repositories does not contain the old repositories' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>First</name></repository>
        <repository><name>Second</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, project.repositories.to_a
  end

  test 'get_removed_repositories returns the repository if new_repositories does not include it' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>10.2</name></repository>
        <repository><name>First</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, [repositories(:repositories_96)]
  end

  test 'get_removed_repositories returns no repository if new_repositories matches old_repositories' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>10.2</name></repository>
        <repository><name>repo</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, []
  end

  test 'get_removed_repositories returns all repositories if new_repositories is empty' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, project.repositories.to_a
  end

  test 'get_removed_repositories returns nothing if repositories is empty' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories.destroy_all

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>First</name></repository>
        <repository><name>Second</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, []
  end

  test 'get_removed_repositories does not include repositories which belong to a remote project' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    first_repository = project.repositories.first

    repository = repositories(:repositories_96)
    repository.remote_project_name = "my_remote_repository"
    repository.save
    project.repositories << repository

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, [first_repository]
  end

  test 'check repositories returns no error if no linking and no linking taget repository exists' do
    User.current = users(:Iggy)
    actual = Project.check_repositories(@project.repositories)
    assert_equal actual, {}
  end

  test 'check repositories returns an error if a linking repository exists' do
    User.current = users(:Iggy)

    path = path_elements(:record_0)
    repository = @project.repositories.first
    repository.links << path

    actual = Project.check_repositories(@project.repositories)
    expected = {
        error: "Unable to delete repository; following repositories depend on this project:\nhome:tom/home_coolo_standard"
    }

    assert_equal actual, expected
  end

  test 'check repositories returns an error if a linking target repository exists' do
    User.current = users(:Iggy)

    release_target = release_targets(:release_targets_913785863)
    repository = @project.repositories.first
    repository.targetlinks << release_target

    actual = Project.check_repositories(@project.repositories)
    expected = {
        error: "Unable to delete repository; following target repositories depend on this project:\nhome:Iggy/10.2"
    }

    assert_equal actual, expected
  end

  test 'linked_packages returns all packages from projects inherited by one level' do
    child = projects('BaseDistro2.0_LinkedUpdateProject')

    assert_equal [["pack2", "BaseDistro2.0"], ["pack2.linked", "BaseDistro2.0"],
                  ["pack_local", "BaseDistro2.0:LinkedUpdateProject"]],
                 child.expand_all_packages
  end

  def test_all_packages_from_projects_inherited_by_two_levels_and_two_links_in_project
    Backend::Test.without_global_write_through do
      parent2 = projects('BaseDistro2.0')
      parent1 = projects('BaseDistro2.0_LinkedUpdateProject')
      child = projects('Apache')

      parent2.linking_to.create(project: parent2,
                                 linked_db_project_id: projects('home_Iggy').id,
                                 position: 1)

      child.linking_to.create(project: child,
                                 linked_db_project_id: parent1.id,
                                 position: 1)

      child.linking_to.create(project: child,
                                  linked_db_project_id: parent2.id,
                                  position: 2)

      result = projects('home_Iggy').packages + child.packages + parent1.packages + parent2.packages
      result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

      assert_equal result, child.expand_all_packages
    end
  end

  def test_linked_packages_does_not_return_packages_overwritten_by_the_actual_project
    Backend::Test.without_global_write_through do
      parent = projects('BaseDistro2.0')
      child = projects('BaseDistro2.0_LinkedUpdateProject')

      pack2 = parent.packages.where(name: 'pack2').first
      child.packages << pack2.dup

      assert_equal [["pack2", "BaseDistro2.0:LinkedUpdateProject"],
                    ["pack2.linked", "BaseDistro2.0"],
                    ["pack_local", "BaseDistro2.0:LinkedUpdateProject"]],
                   child.expand_all_packages
    end
  end

  def test_linked_packages_does_not_return_packages_overwritten_by_the_actual_project_inherited_from_two_levels
    Backend::Test.without_global_write_through do
      parent2 = projects('BaseDistro2.0')
      parent1 = projects('BaseDistro2.0_LinkedUpdateProject')
      child = projects('Apache')

      child.linking_to.create(project: child,
                                  linked_db_project_id: parent1.id,
                                  position: 1)

      child.linking_to.create(project: child,
                                  linked_db_project_id: parent2.id,
                                  position: 2)

      pack2 = parent2.packages.where(name: 'pack2').first
      child.packages << pack2.dup

      result = child.packages + parent1.packages + parent2.packages.where(name: 'pack2.linked')
      result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

      assert_equal result, child.expand_all_packages
    end
  end

  def test_linked_packages_returns_overwritten_packages_from_the_project_with_the_highest_position
    Backend::Test.without_global_write_through do
      base_distro = projects('BaseDistro2.0')
      base_distro_update = projects('BaseDistro2.0_LinkedUpdateProject')

      child = projects('Apache')

      child.linking_to.create(project: child,
                                  linked_db_project_id: base_distro_update.id,
                                  position: 1)

      child.linking_to.create(project: child,
                                  linked_db_project_id: base_distro.id,
                                  position: 2)

      pack2 = base_distro.packages.where(name: 'pack2').first
      base_distro_update.packages << pack2.dup

      result = child.packages + base_distro_update.packages + base_distro.packages.where(name: 'pack2.linked')
      result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

      assert_equal result, child.expand_all_packages
    end
  end

  test 'config file exists and have the right content' do
    assert_equal @project.config.to_s, File.read("test/fixtures/files/home_iggy_project_config.txt").strip
  end

  test 'update config file and reload it, it also should have the right content' do
    project_config = File.read("test/fixtures/files/home_iggy_project_config.txt")
    new_project_config = File.read("test/fixtures/files/new_home_iggy_project_config.txt")

    User.current = users(:Iggy)
    query_params = {user: User.current.login, comment: "Updated by test"}
    assert @project.config.save(query_params, new_project_config)
    assert_equal @project.config.to_s, new_project_config

    # Leave the backend file as it was
    assert @project.config.save(query_params, project_config)
  end

  def test_open_requests
    apache = projects(:Apache)
    assert_equal apache.open_requests, { reviews: [1000, 10, 4], targets: [5], incidents: [], maintenance_release: [] }

    maintenance = projects(:My_Maintenance)
    assert_equal maintenance.open_requests, { reviews: [], targets: [6], incidents: [6], maintenance_release: [7] }
  end
end
