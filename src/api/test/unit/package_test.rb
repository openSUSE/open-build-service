require_relative '../test_helper'

SimpleCov.command_name('minitest')

class PackageTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    super
    @package = packages(:home_Iggy_TestPack)
    User.session = users(:Iggy)
  end

  def test_flags_to_axml
    # check precondition
    assert_equal 2, @package.flags.of_type('build').size
    assert_equal 1, @package.flags.of_type('publish').size
    assert_equal 1, @package.flags.of_type('debuginfo').size

    xml_string = @package.to_axml

    # check the results
    xml = REXML::Document.new(xml_string)
    assert_equal 1, xml.root.get_elements('/package/build').size
    assert_equal 2, xml.root.get_elements('/package/build/*').size

    assert_equal 1, xml.root.get_elements('/package/publish').size
    assert_equal 1, xml.root.get_elements('/package/publish/*').size

    assert_equal 1, xml.root.get_elements('/package/debuginfo').size
    assert_equal 1, xml.root.get_elements('/package/debuginfo/*').size
  end

  def test_add_new_flags_from_xml
    # precondition check
    @package.flags.destroy_all
    @package.reload
    assert_equal 0, @package.flags.size

    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
        <build>
          <enable repository='10.2' arch='i586'/>
        </build>
        <publish>
          <enable repository='10.1' arch='x86_64'/>
        </publish>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
        <url></url>
      </package>"
    )

    position = 1
    %w[build publish debuginfo].each do |flagtype|
      position = @package.update_flags(axml, flagtype, position)
    end

    @package.save
    @package.reload

    # check results
    assert_equal 1, @package.flags.of_type('build').size
    assert_equal 'enable', @package.flags.of_type('build')[0].status
    assert_equal '10.2', @package.flags.of_type('build')[0].repo
    assert_equal 'i586', @package.flags.of_type('build')[0].architecture.name
    assert_equal 1, @package.flags.of_type('build')[0].position
    assert_nil @package.flags.of_type('build')[0].project
    assert_equal 'TestPack', @package.flags.of_type('build')[0].package.name
    assert_equal true, @package.enabled_for?('build', '10.2', 'i586')
    assert_equal false, @package.disabled_for?('build', '10.2', 'i586')

    assert_equal 1, @package.flags.of_type('publish').size
    assert_equal 'enable', @package.flags.of_type('publish')[0].status
    assert_equal '10.1', @package.flags.of_type('publish')[0].repo
    assert_equal 'x86_64', @package.flags.of_type('publish')[0].architecture.name
    assert_equal 2, @package.flags.of_type('publish')[0].position
    assert_nil @package.flags.of_type('publish')[0].project
    assert_equal 'TestPack', @package.flags.of_type('publish')[0].package.name

    assert_equal 1, @package.flags.of_type('debuginfo').size
    assert_equal 'disable', @package.flags.of_type('debuginfo')[0].status
    assert_equal '10.0', @package.flags.of_type('debuginfo')[0].repo
    assert_equal 'i586', @package.flags.of_type('debuginfo')[0].architecture.name
    assert_equal 3, @package.flags.of_type('debuginfo')[0].position
    assert_nil @package.flags.of_type('debuginfo')[0].project
    assert_equal 'TestPack', @package.flags.of_type('debuginfo')[0].package.name
  end

  def test_delete_flags_through_xml
    # check precondition
    assert_equal 2, @package.flags.of_type('build').size
    assert_equal 1, @package.flags.of_type('publish').size

    # package is given as axml
    axml = Xmlhash.parse(
      "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
      </package>"
    )

    # first update build-flags, should only delete build-flags
    @package.update_all_flags(axml)
    assert_equal 0, @package.flags.of_type('build').size
    assert_equal 0, @package.flags.of_type('publish').size
  end

  def test_render
    xml = packages(:kde4_kdelibs).render_xml
    assert_equal Xmlhash.parse(xml), 'name' => 'kdelibs',
                                     'project' => 'kde4', 'title' => 'blub', 'description' => 'blub',
                                     'devel' => { 'project' => 'home:coolo:test', 'package' => 'kdelibs_DEVEL_package' },
                                     'person' => [{ 'userid' => 'fredlibs', 'role' => 'maintainer' },
                                                  { 'userid' => 'adrian', 'role' => 'reviewer' }],
                                     'group' => { 'groupid' => 'test_group', 'role' => 'maintainer' }
  end

  def test_can_be_deleted
    assert_not packages(:kde4_kdelibs).check_weak_dependencies!
  end

  def test_store
    orig = Xmlhash.parse(@package.to_axml)

    assert_raise(Package::SaveError) do
      @package.update_from_xml(Xmlhash.parse(
                                 "<package name='TestPack' project='home:Iggy'>
                                   <title>My Test package</title>
                                   <description></description>
                                   <devel project='Notexistent'/>
                                 </package>"
                               ))
    end
    assert_raise(Package::SaveError) do
      @package.update_from_xml(Xmlhash.parse(
                                 "<package name='TestPack' project='home:Iggy'>
                                   <title>My Test package</title>
                                   <description></description>
                                   <devel project='home:Iggy' package='nothing'/>
                                 </package>"
                               ))
    end

    assert_raise(NotFoundError) do
      @package.update_from_xml(Xmlhash.parse(
                                 "<package name='TestBack' project='home:Iggy'>
                                   <title>My Test package</title>
                                   <description></description>
                                   <person userid='alice' role='maintainer'/>
                                 </package>"
                               ))
    end

    assert_raise(HasRelationships::SaveError) do
      @package.update_from_xml(Xmlhash.parse(
                                 "<package name='TestBack' project='home:Iggy'>
                                   <title>My Test package</title>
                                   <description></description>
                                   <person userid='tom' role='coolman'/>
                                 </package>"
                               ))
    end

    assert_equal orig, Xmlhash.parse(@package.to_axml)
    assert @package.update_from_xml(Xmlhash.parse(
                                      "<package name='TestPack' project='home:Iggy'>
                                        <title>My Test package</title>
                                        <description></description>
                                        <person userid='fred' role='bugowner'/>
                                        <person userid='Iggy' role='maintainer'/>
                                      </package>"
                                    ))
  end

  def test_add_user
    orig = @package.render_xml
    @package.add_user('tom', 'maintainer')
    @package.update_from_xml(Xmlhash.parse(orig))

    assert_raise(Relationship::AddRole::SaveError) do
      @package.add_user('tom', 'Admin')
    end
    assert_equal orig, @package.render_xml
  end

  def test_names_are_case_sensitive
    Backend::Test.without_global_write_through do
      np = @package.project.packages.new(name: 'testpack')
      xh = Xmlhash.parse(@package.to_axml)
      np.save!
      np.update_from_xml(xh)
      assert_equal np.name, 'testpack'
      assert np.id.positive?
      assert np.id != @package.id
    end
  end

  test 'invalid names are catched' do
    @package.name = '_coolproject'
    assert_not @package.save
    assert_raise(ActiveRecord::RecordInvalid) do
      @package.save!
    end
    @package.name = Faker::Lorem.characters(number: 255)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      @package.save!
    end
    assert_match(/Name is too long/, e.message)
    @package.name = '_product'
    assert @package.valid?
    @package.name = '.product'
    assert_not @package.valid?
    @package.name = 'product.i586'
    assert @package.valid?
  end

  test 'utf8 input' do
    xml = '<package name="libconfig" project="home:coolo">
  <title>libconfig &#8211; C/C++ Configuration File Library</title>
  <description>Libconfig is a simple library for processing structured configuration files,
  like this one: test.cfg. This file format is more compact and more readable than XML.
  And unlike XML, it is type-aware, so it is not necessary to do string parsing in application code.

  Libconfig is very compact &#8212; just 38K for the stripped C shared library (less than one-fourth the
  size of the expat XML parser library) and 66K for the stripped C++ shared library. This makes it well-suited
  for memory-constrained systems like handheld devices.

  The library includes bindings for both the C and C++ languages. It works on POSIX-compliant UNIX
  systems (GNU/Linux, Mac OS X, Solaris, FreeBSD) and Windows (2000, XP and later).
  </description>
  </package>'
    xh = Xmlhash.parse(xml)
    @package.update_from_xml(xh)
  end

  def test_activity
    Backend::Test.without_global_write_through do
      travel_to(Date.new(2010, 1, 1))
      project = projects(:home_Iggy)
      newyear = project.packages.create!(name: 'newyear')
      # freshly created it should have 20
      assert_equal 20, newyear.activity_index
      assert_in_delta(20.0, newyear.activity, 0.2)

      # a month later now
      travel_to(Date.new(2010, 2, 1))
      assert_in_delta(15.9, newyear.activity, 0.2)

      # a month later now
      travel_to(Date.new(2010, 3, 1))
      assert_in_delta(12.9, newyear.activity, 0.2)

      newyear.title = 'Just a silly update'
      newyear.save
      assert_in_delta(22.9, newyear.activity, 0.2)

      travel_to(Date.new(2010, 4, 1))
      assert_in_delta(18.3, newyear.activity, 0.2)

      travel_to(Date.new(2010, 5, 1))
      assert_in_delta(14.7, newyear.activity, 0.2)

      newyear.title = 'Just a silly update 2'
      newyear.save
      assert_in_delta(24.7, newyear.activity, 0.2)
      newyear.title = 'Just a silly update 3'
      newyear.save
      # activity stays the same  now
      assert_in_delta(24.7, newyear.activity, 0.2)

      # an hour later perhaps?
      travel(1.hour)
      newyear.title = 'Just a silly update 4'
      newyear.save
      assert_in_delta(25.1, newyear.activity, 0.2)

      # and commit every day?
      travel(90_000.seconds)
      newyear.title = 'Just a silly update 5'
      newyear.save
      assert_in_delta(34.9, newyear.activity, 0.2)

      travel(90_000.seconds)
      newyear.title = 'Just a silly update 6'
      newyear.save
      assert_in_delta(44.6, newyear.activity, 0.2)

      travel(90_000.seconds)
      newyear.title = 'Just a silly update 7'
      newyear.save
      assert_in_delta(54.2, newyear.activity, 0.2)

      travel(90_000.seconds)
      newyear.title = 'Just a silly update 8'
      newyear.save
      assert_in_delta(63.8, newyear.activity, 0.2)

      travel(90_000.seconds)
      newyear.title = 'Just a silly update 8'
      newyear.save
      assert_in_delta(73.5, newyear.activity, 0.2)
    end
  end

  test 'fixtures name' do
    assert_equal 'home_Iggy_TestPack', packages(:home_Iggy_TestPack).fixtures_name
  end

  test 'default scope does not include forbidden projects' do
    # assert that unscoped the forbidden projects are included
    assert Package.unscoped.where(project_id: Relationship.forbidden_project_ids).any?

    # assert that with default scope the forbidden projects are not included
    assert_not Package.where(project_id: Relationship.forbidden_project_ids).any?
  end
end
